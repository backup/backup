# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::S3 do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::S3.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Storage::Base' do
    let(:cycling_supported) { true }
  end

  describe '#initialize' do
    it 'provides default values' do
      expect( storage.storage_id        ).to be_nil
      expect( storage.keep              ).to be_nil
      expect( storage.access_key_id     ).to be_nil
      expect( storage.secret_access_key ).to be_nil
      expect( storage.bucket            ).to be_nil
      expect( storage.region            ).to be_nil
      expect( storage.path              ).to eq 'backups'
      expect( storage.chunk_size        ).to be 5
      expect( storage.max_retries       ).to be 10
      expect( storage.retry_waitsec     ).to be 30
      expect( storage.encryption        ).to be_nil
      expect( storage.storage_class     ).to be :standard
    end

    it 'configures the storage' do
      storage = Storage::S3.new(model, :my_id) do |s3|
        s3.keep               = 2
        s3.access_key_id      = 'my_access_key_id'
        s3.secret_access_key  = 'my_secret_access_key'
        s3.bucket             = 'my_bucket'
        s3.region             = 'my_region'
        s3.path               = 'my/path'
        s3.chunk_size         = 10
        s3.max_retries        = 5
        s3.retry_waitsec      = 60
        s3.encryption         = 'aes256'
        s3.storage_class      = :reduced_redundancy
      end

      expect( storage.storage_id        ).to eq 'my_id'
      expect( storage.keep              ).to be 2
      expect( storage.access_key_id     ).to eq 'my_access_key_id'
      expect( storage.secret_access_key ).to eq 'my_secret_access_key'
      expect( storage.bucket            ).to eq 'my_bucket'
      expect( storage.region            ).to eq 'my_region'
      expect( storage.path              ).to eq 'my/path'
      expect( storage.chunk_size        ).to be 10
      expect( storage.max_retries       ).to be 5
      expect( storage.retry_waitsec     ).to be 60
      expect( storage.encryption        ).to eq 'aes256'
      expect( storage.storage_class     ).to eq :reduced_redundancy
    end

    it 'strips leading path separator' do
      storage = Storage::S3.new(model) do |s3|
        s3.path = '/this/path'
      end
      expect( storage.path ).to eq 'this/path'
    end

  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    before do
      storage.access_key_id     = 'my_access_key_id'
      storage.secret_access_key = 'my_secret_access_key'
      storage.region            = 'my_region'
    end

    it 'creates a new connection' do
      Fog::Storage.expects(:new).with(
        :provider               => 'AWS',
        :aws_access_key_id      => 'my_access_key_id',
        :aws_secret_access_key  => 'my_secret_access_key',
        :region                 => 'my_region'
      ).returns(connection)
      connection.expects(:sync_clock)
      expect( storage.send(:connection) ).to eq connection
    end

    it 'caches the connection' do
      Fog::Storage.expects(:new).once.returns(connection)
      connection.expects(:sync_clock).once
      expect( storage.send(:connection) ).to eq connection
      expect( storage.send(:connection) ).to eq connection
    end

  end # describe '#connection'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:uploader) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.package.stubs(:filenames).returns(
        ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
      storage.stubs(:connection).returns(connection)
      storage.bucket = 'my_bucket'
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'transfers the package files' do
      src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
      dest = File.join(remote_path, 'test_trigger.tar-aa')

      Logger.expects(:info).in_sequence(s).with("Storing 'my_bucket/#{ dest }'...")
      Storage::S3::Uploader.expects(:new).in_sequence(s).
          with(storage, connection, src, dest).returns(uploader)
      uploader.expects(:run).in_sequence(s)

      src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
      dest = File.join(remote_path, 'test_trigger.tar-ab')

      Logger.expects(:info).in_sequence(s).with("Storing 'my_bucket/#{ dest }'...")
      Storage::S3::Uploader.expects(:new).in_sequence(s).
          with(storage, connection, src, dest).returns(uploader)
      uploader.expects(:run).in_sequence(s)

      storage.send(:transfer!)
    end

  end # describe '#transfer!'

  describe '#remove!' do
    let(:connection) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
    let(:package) {
      stub( # loaded from YAML storage file
        :trigger    => 'test_trigger',
        :time       => timestamp
      )
    }
    let(:response) { mock }
    let(:bucket_with_keys) {
      { 'Contents' => [ { 'Key' => 'file_a' }, { 'Key' => 'file_b' } ] }
    }
    let(:bucket_without_keys) {
      { 'Contents' => [] }
    }

    before do
      Timecop.freeze
      storage.stubs(:connection).returns(connection)
      storage.bucket = 'my_bucket'
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'removes the given package from the remote' do
      Logger.expects(:info).with("Removing backup package dated #{ timestamp }...")

      connection.expects(:get_bucket).
          with('my_bucket', :prefix => remote_path).returns(response)
      response.expects(:body).returns(bucket_with_keys)

      connection.expects(:delete_multiple_objects).
          with('my_bucket', ['file_a', 'file_b'])

      storage.send(:remove!, package)
    end

    it 'raises an error if remote package is missing' do
      Logger.expects(:info).with("Removing backup package dated #{ timestamp }...")

      connection.expects(:get_bucket).
          with('my_bucket', :prefix => remote_path).returns(response)
      response.expects(:body).returns(bucket_without_keys)

      connection.expects(:delete_multiple_objects).never

      expect do
        storage.send(:remove!, package)
      end.to raise_error(
        Errors::Storage::S3::NotFoundError,
        "Storage::S3::NotFoundError: Package at '#{ remote_path }' not found"
      )
    end

  end # describe '#remove!'

  describe Storage::S3::Uploader do
    let(:connection) { mock }
    let(:uploader) {
      Storage::S3::Uploader.new(storage, connection, 'src/file', 'dest/file')
    }
    let(:s) { sequence '' }

    before do
      storage.bucket = 'my_bucket'
      uploader.stubs(:sleep)
    end

    describe '#run' do
      context 'when chunk_size is 0' do
        let(:uploader) {
          storage.chunk_size = 0
          Storage::S3::Uploader.new(storage, connection, 'src/file', 'dest/file')
        }

        it 'uploads file using put_object' do
          File.expects(:size).never
          uploader.expects(:initiate_multipart).never
          uploader.expects(:upload_parts).never
          uploader.expects(:complete_multipart).never

          uploader.expects(:upload)

          uploader.run
        end
      end

      context 'when src file is greater than chunk_size' do
        before do
          File.expects(:size).with('src/file').returns(1024**2 * 6)
        end

        it 'uploads file using multipart upload' do
          uploader.expects(:upload).never

          uploader.expects(:initiate_multipart)
          uploader.expects(:upload_parts)
          uploader.expects(:complete_multipart)

          uploader.run
        end
      end

      context 'when src file is less than or equal to chunk_size' do
        before do
          File.expects(:size).with('src/file').returns(1024**2 * 5)
        end

        it 'uploads file using put_object' do
          uploader.expects(:initiate_multipart).never
          uploader.expects(:upload_parts).never
          uploader.expects(:complete_multipart).never

          uploader.expects(:upload)

          uploader.run
        end
      end

      context 'when an error is raised' do
        it 'wraps the error' do
          File.stubs(:size).raises('error message')

          expect do
            uploader.run
          end.to raise_error(Errors::Storage::S3::UploaderError) {|err|
            expect( err.message ).to match('Upload Failed!')
            expect( err.message ).to match('RuntimeError: error message')
          }
        end
      end
    end # describe '#run'

    describe '#upload' do
      let(:file) { mock }
      let(:digest_file) { mock }

      before do
        Digest::MD5.expects(:file).in_sequence(s).
            with('src/file').returns(digest_file)
        digest_file.expects(:digest).in_sequence(s).
            returns('md5_digest')
        Base64.expects(:encode64).in_sequence(s).
            with('md5_digest').returns("encoded_digest\n")
        uploader.stubs(:headers).returns({ 'some' => 'headers'})
      end

      it 'uploads file using put_object' do
        File.expects(:open).in_sequence(s).with('src/file', 'r').yields(file)
        connection.expects(:put_object).in_sequence(s).with(
          'my_bucket', 'dest/file', file,
          { 'some' => 'headers', 'Content-MD5' => 'encoded_digest' }
        )

        uploader.send(:upload)
      end

      it 'retries on errors' do
        File.expects(:open).in_sequence(s).with('src/file', 'r').yields(file)
        connection.expects(:put_object).in_sequence(s).with(
          'my_bucket', 'dest/file', file,
          { 'some' => 'headers', 'Content-MD5' => 'encoded_digest' }
        ).raises('error message')

        File.expects(:open).in_sequence(s).with('src/file', 'r').yields(file)
        connection.expects(:put_object).in_sequence(s).with(
          'my_bucket', 'dest/file', file,
          { 'some' => 'headers', 'Content-MD5' => 'encoded_digest' }
        )

        uploader.send(:upload)
      end
    end # describe '#upload'

    describe '#initiate_multipart' do
      let(:response) { mock }

      before do
        response.stubs(:body).returns({ 'UploadId' => 123 })
        uploader.stubs(:headers).returns({ 'some' => 'headers'})
      end

      it 'initiates the multipart upload' do
        connection.expects(:initiate_multipart_upload).with(
          'my_bucket', 'dest/file', { 'some' => 'headers' }
        ).returns(response)

        uploader.send(:initiate_multipart)
        expect( uploader.upload_id ).to be 123
      end

      it 'retries on errors' do
        connection.expects(:initiate_multipart_upload).in_sequence(s).with(
          'my_bucket', 'dest/file', { 'some' => 'headers' }
        ).raises('error message')

        connection.expects(:initiate_multipart_upload).in_sequence(s).with(
          'my_bucket', 'dest/file', { 'some' => 'headers' }
        ).returns(response)

        uploader.send(:initiate_multipart)
        expect( uploader.upload_id ).to be 123
      end
    end # describe '#initiate_multipart'

    describe '#upload_parts' do
      let(:file) { mock }
      let(:chunk_size) { 1024**2 * 5 }
      let(:response) { mock }

      before do
        uploader.stubs(:upload_id).returns(123)
        uploader.expects(:headers).never
      end

      it 'uploads the file in chunks' do
        File.expects(:open).in_sequence(s).with('src/file', 'r').yields(file)

        # first chunk
        file.expects(:read).in_sequence(s).
            with(chunk_size).returns('chunk one')
        Digest::MD5.expects(:digest).in_sequence(s).
            with('chunk one').returns('chunk one digest')
        Base64.expects(:encode64).in_sequence(s).
            with('chunk one digest').returns("encoded chunk one digest\n")
        connection.expects(:upload_part).in_sequence(s).
            with('my_bucket', 'dest/file', 123, 1, 'chunk one',
                 { 'Content-MD5' => 'encoded chunk one digest' }).returns(response)
        response.expects(:headers).in_sequence(s).
            returns({ 'ETag' => 'part one etag' })

        # second chunk
        file.expects(:read).in_sequence(s).
            with(chunk_size).returns('chunk two')
        Digest::MD5.expects(:digest).in_sequence(s).
            with('chunk two').returns('chunk two digest')
        Base64.expects(:encode64).in_sequence(s).
            with('chunk two digest').returns("encoded chunk two digest\n")
        connection.expects(:upload_part).in_sequence(s).
            with('my_bucket', 'dest/file', 123, 2, 'chunk two',
                 { 'Content-MD5' => 'encoded chunk two digest' }).returns(response)
        response.expects(:headers).in_sequence(s).
            returns({ 'ETag' => 'part two etag' })

        # EOF
        file.expects(:read).in_sequence(s).with(chunk_size).returns(nil)

        uploader.send(:upload_parts)
        expect( uploader.parts ).to eq ['part one etag', 'part two etag']
      end

      it 'retries failed chunks' do
        File.expects(:open).in_sequence(s).with('src/file', 'r').yields(file)

        file.expects(:read).in_sequence(s).
            with(chunk_size).returns('chunk one')
        Digest::MD5.expects(:digest).in_sequence(s).
            with('chunk one').returns('chunk one digest')
        Base64.expects(:encode64).in_sequence(s).
            with('chunk one digest').returns("encoded chunk one digest\n")

        # chunk failure
        connection.expects(:upload_part).in_sequence(s).
            with('my_bucket', 'dest/file', 123, 1, 'chunk one',
                 { 'Content-MD5' => 'encoded chunk one digest' }).
            raises('error message')

        # chunk retry
        connection.expects(:upload_part).in_sequence(s).
            with('my_bucket', 'dest/file', 123, 1, 'chunk one',
                 { 'Content-MD5' => 'encoded chunk one digest' }).
            returns(response)
        response.expects(:headers).in_sequence(s).
            returns({ 'ETag' => 'part one etag' })

        # EOF
        file.expects(:read).in_sequence(s).with(chunk_size).returns(nil)

        uploader.send(:upload_parts)
        expect( uploader.parts ).to eq ['part one etag']
      end

    end # describe '#upload_parts'

    describe '#headers' do
      it 'returns empty headers by default' do
        # defaults for the storage
        expect( uploader.encryption ).to be_nil
        expect( uploader.storage_class ).to eq :standard

        uploader.send(:headers).should == {}
      end

      it 'returns headers for server-side encryption' do
        ['aes256', :aes256].each do |arg|
          uploader.stubs(:encryption).returns(arg)

          uploader.send(:headers).should ==
              { 'x-amz-server-side-encryption' => 'AES256' }
        end
      end

      it 'returns headers for reduced redundancy storage' do
        ['reduced_redundancy', :reduced_redundancy].each do |arg|
          uploader.stubs(:storage_class).returns(arg)

          uploader.send(:headers).should ==
              { 'x-amz-storage-class' => 'REDUCED_REDUNDANCY' }
        end
      end

      it 'returns headers for both' do
        uploader.stubs(:encryption).returns(:aes256)
        uploader.stubs(:storage_class).returns(:reduced_redundancy)
        uploader.send(:headers).should ==
            { 'x-amz-server-side-encryption' => 'AES256',
              'x-amz-storage-class' => 'REDUCED_REDUNDANCY' }
      end

      it 'returns empty headers for empty values' do
        uploader.stubs(:encryption).returns('')
        uploader.stubs(:storage_class).returns('')
        uploader.send(:headers).should == {}
      end
    end # describe '#headers

    describe '#complete_multipart' do
      before do
        uploader.stubs(:upload_id).returns(123)
        uploader.stubs(:parts).returns(['etag_a', 'etag_b'])
      end

      it 'completes the multipart upload' do
        connection.expects(:complete_multipart_upload).
            with('my_bucket', 'dest/file', 123, ['etag_a', 'etag_b'])

        uploader.send(:complete_multipart)
      end

      it 'retries on errors' do
        connection.expects(:complete_multipart_upload).in_sequence(s).
            with('my_bucket', 'dest/file', 123, ['etag_a', 'etag_b']).
            raises('error message')

        connection.expects(:complete_multipart_upload).in_sequence(s).
            with('my_bucket', 'dest/file', 123, ['etag_a', 'etag_b'])

        uploader.send(:complete_multipart)
      end
    end # describe '#complete_multipart'

    describe '#with_retries' do
      it 'retries the given block max_retries times' do
        errors_collected = []
        Logger.expects(:info).times(10).with do |err|
          errors_collected << err
        end
        uploader.expects(:sleep).times(10).with(30)

        expect do
          uploader.send(:with_retries) do
            raise 'error message'
          end
        end.to raise_error(RuntimeError, 'error message')

        10.times do |n|
          expect( errors_collected.shift.message ).
              to match(/Retry ##{ n + 1 } of 10./)
        end
      end
    end # describe '#with_retries'

    describe '#error_with' do
      it 'avoids wrapping Excon::Errors::HTTPStatusError' do
        ex = Excon::Errors::HTTPStatusError.
            new('excon_message', 'excon_request', 'excon_response')
        err = uploader.send(:error_with, ex, 'my message')

        expect( err ).to be_an_instance_of Errors::Storage::S3::UploaderError
        expect( err.message ).to match('my message')
        expect( err.message ).to match(
          "Excon::Errors::HTTPStatusError\n" +
          "  response => \"excon_response\""
        )
      end

      it 'wraps other errors' do
        ex = StandardError.new('error message')
        err = uploader.send(:error_with, ex, 'my message')

        expect( err ).to be_an_instance_of Errors::Storage::S3::UploaderError
        expect( err.message ).to match('my message')
        expect( err.message ).to match('StandardError: error message')
      end
    end # describe '#error_with'

  end # describe Storage::S3::Uploader

end
end
