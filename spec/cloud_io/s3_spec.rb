# encoding: utf-8
require File.expand_path('../../spec_helper.rb', __FILE__)
require 'backup/cloud_io/s3'

module Backup
describe CloudIO::S3 do
  let(:connection) { mock }

  describe '#upload' do

    context 'with multipart support' do
      let(:cloud_io) { CloudIO::S3.new(:bucket => 'my_bucket', :chunk_size => 5) }
      let(:parts) { mock }

      context 'when src file is larger than chunk_size' do
        before do
          File.expects(:size).with('/src/file').returns(10 * 1024**2)
        end

        it 'uploads using multipart' do
          cloud_io.expects(:initiate_multipart).with('dest/file').returns(1234)
          cloud_io.expects(:upload_parts).with(
            '/src/file', 'dest/file', 1234, 5 * 1024**2, 10 * 1024**2
          ).returns(parts)
          cloud_io.expects(:complete_multipart).with('dest/file', 1234, parts)
          cloud_io.expects(:put_object).never

          cloud_io.upload('/src/file', 'dest/file')
        end
      end

      context 'when src file is not larger than chunk_size' do
        before do
          File.expects(:size).with('/src/file').returns(5 * 1024**2)
        end

        it 'uploads without multipart' do
          cloud_io.expects(:put_object).with('/src/file', 'dest/file')
          cloud_io.expects(:initiate_multipart).never

          cloud_io.upload('/src/file', 'dest/file')
        end
      end

      context 'when chunk_size is too small for the src file' do
        before do
          File.expects(:size).with('/src/file').returns((50_000 * 1024**2) + 1)
        end

        it 'warns and adjusts the chunk_size' do
          cloud_io.expects(:initiate_multipart).with('dest/file').returns(1234)
          cloud_io.expects(:upload_parts).with(
            '/src/file', 'dest/file', 1234, 6 * 1024**2, (50_000 * 1024**2) + 1
          ).returns(parts)
          cloud_io.expects(:complete_multipart).with('dest/file', 1234, parts)
          cloud_io.expects(:put_object).never

          Logger.expects(:warn).with do |err|
            expect( err.message ).to include(
              "#chunk_size of 5 MiB has been adjusted\n  to 6 MiB"
            )
          end

          cloud_io.upload('/src/file', 'dest/file')
        end
      end

      context 'when src file is too large' do
        before do
          File.expects(:size).with('/src/file').
              returns(described_class::MAX_MULTIPART_SIZE + 1)
        end

        it 'raises an error' do
          cloud_io.expects(:initiate_multipart).never
          cloud_io.expects(:put_object).never

          expect do
            cloud_io.upload('/src/file', 'dest/file')
          end.to raise_error(CloudIO::FileSizeError)
        end
      end

    end # context 'with multipart support'

    context 'without multipart support' do
      let(:cloud_io) { CloudIO::S3.new(:bucket => 'my_bucket', :chunk_size => 0) }

      before do
        cloud_io.expects(:initiate_multipart).never
      end

      context 'when src file size is ok' do
        before do
          File.expects(:size).with('/src/file').
              returns(described_class::MAX_FILE_SIZE)
        end

        it 'uploads using put_object' do
          cloud_io.expects(:put_object).with('/src/file', 'dest/file')

          cloud_io.upload('/src/file', 'dest/file')
        end
      end

      context 'when src file is too large' do
        before do
          File.expects(:size).with('/src/file').
              returns(described_class::MAX_FILE_SIZE + 1)
        end

        it 'raises an error' do
          cloud_io.expects(:put_object).never

          expect do
            cloud_io.upload('/src/file', 'dest/file')
          end.to raise_error(CloudIO::FileSizeError)
        end
      end

    end # context 'without multipart support'

  end # describe '#upload'

  describe '#objects' do
    let(:cloud_io) {
      CloudIO::S3.new(
        :bucket => 'my_bucket',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }

    before do
      cloud_io.stubs(:connection).returns(connection)
    end

    it 'ensures prefix ends with /' do
      connection.expects(:get_bucket).
          with('my_bucket', { 'prefix' => 'foo/bar/' }).
          returns(stub(:body => { 'Contents' => [] }))
      expect( cloud_io.objects('foo/bar') ).to eq []
    end

    it 'returns an empty array when no objects are found' do
      connection.expects(:get_bucket).
          with('my_bucket', { 'prefix' => 'foo/bar/' }).
          returns(stub(:body => { 'Contents' => [] }))
      expect( cloud_io.objects('foo/bar/') ).to eq []
    end

    context 'when returned objects are not truncated' do
      let(:resp_body) {
        { 'IsTruncated' => false,
          'Contents' => 10.times.map do |n|
            { 'Key' => "key_#{ n }",
              'ETag' => "etag_#{ n }",
              'StorageClass' => 'STANDARD' }
          end
        }
      }

      it 'returns all objects' do
        cloud_io.expects(:with_retries).
            with("GET 'my_bucket/foo/bar/*'").yields
        connection.expects(:get_bucket).
            with('my_bucket', { 'prefix' => 'foo/bar/' }).
            returns(stub(:body => resp_body))

        objects = cloud_io.objects('foo/bar/')
        expect( objects.count ).to be 10
        objects.each_with_index do |object, n|
          expect( object.key ).to eq("key_#{ n }")
          expect( object.etag ).to eq("etag_#{ n }")
          expect( object.storage_class ).to eq('STANDARD')
        end
      end
    end

    context 'when returned objects are truncated' do
      let(:resp_body_a) {
        { 'IsTruncated' => true,
          'Contents' => (0..6).map do |n|
            { 'Key' => "key_#{ n }",
              'ETag' => "etag_#{ n }",
              'StorageClass' => 'STANDARD' }
          end
        }
      }
      let(:resp_body_b) {
        { 'IsTruncated' => false,
          'Contents' => (7..9).map do |n|
            { 'Key' => "key_#{ n }",
              'ETag' => "etag_#{ n }",
              'StorageClass' => 'STANDARD' }
          end
        }
      }

      it 'returns all objects' do
        cloud_io.expects(:with_retries).twice.
            with("GET 'my_bucket/foo/bar/*'").yields
        connection.expects(:get_bucket).
            with('my_bucket', { 'prefix' => 'foo/bar/' }).
            returns(stub(:body => resp_body_a))
        connection.expects(:get_bucket).
            with('my_bucket', { 'prefix' => 'foo/bar/', 'marker' => 'key_6' }).
            returns(stub(:body => resp_body_b))

        objects = cloud_io.objects('foo/bar/')
        expect( objects.count ).to be 10
        objects.each_with_index do |object, n|
          expect( object.key ).to eq("key_#{ n }")
          expect( object.etag ).to eq("etag_#{ n }")
          expect( object.storage_class ).to eq('STANDARD')
        end
      end

      it 'retries on errors' do
        connection.expects(:get_bucket).twice.
            with('my_bucket', { 'prefix' => 'foo/bar/' }).
            raises('error').then.
            returns(stub(:body => resp_body_a))
        connection.expects(:get_bucket).twice.
            with('my_bucket', { 'prefix' => 'foo/bar/', 'marker' => 'key_6' }).
            raises('error').then.
            returns(stub(:body => resp_body_b))

        objects = cloud_io.objects('foo/bar/')
        expect( objects.count ).to be 10
        objects.each_with_index do |object, n|
          expect( object.key ).to eq("key_#{ n }")
          expect( object.etag ).to eq("etag_#{ n }")
          expect( object.storage_class ).to eq('STANDARD')
        end
      end
    end

  end # describe '#objects'

  describe '#head_object' do
    let(:cloud_io) {
      CloudIO::S3.new(
        :bucket => 'my_bucket',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }

    before do
      cloud_io.stubs(:connection).returns(connection)
    end

    it 'returns head_object response with retries' do
      object = stub(:key => 'obj_key')
      connection.expects(:head_object).twice.
          with('my_bucket', 'obj_key').
          raises('error').then.returns(:response)
      expect( cloud_io.head_object(object) ).to eq :response
    end
  end # describe '#head_object'

  describe '#delete' do
    let(:cloud_io) {
      CloudIO::S3.new(
        :bucket => 'my_bucket',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }
    let(:resp_ok) { stub(:body => { 'DeleteResult' => [] }) }
    let(:resp_bad) {
      stub(:body => {
          'DeleteResult' => [
            { 'Error' => {
                'Key' => 'obj_key',
                'Code' => 'InternalError',
                'Message' => 'We encountered an internal error. Please try again.'
              }
            }
          ]
        }
      )
    }

    before do
      cloud_io.stubs(:connection).returns(connection)
    end

    it 'accepts a single Object' do
      object = described_class::Object.new(:foo, { 'Key' => 'obj_key' })
      cloud_io.expects(:with_retries).with('DELETE Multiple Objects').yields
      connection.expects(:delete_multiple_objects).with(
        'my_bucket', ['obj_key'], { :quiet => true }
      ).returns(resp_ok)
      cloud_io.delete(object)
    end

    it 'accepts multiple Objects' do
      object_a = described_class::Object.new(:foo, { 'Key' => 'obj_key_a' })
      object_b = described_class::Object.new(:foo, { 'Key' => 'obj_key_b' })
      cloud_io.expects(:with_retries).with('DELETE Multiple Objects').yields
      connection.expects(:delete_multiple_objects).with(
        'my_bucket', ['obj_key_a', 'obj_key_b'], { :quiet => true }
      ).returns(resp_ok)

      objects = [object_a, object_b]
      expect do
        cloud_io.delete(objects)
      end.not_to change { objects }
    end

    it 'accepts a single key' do
      cloud_io.expects(:with_retries).with('DELETE Multiple Objects').yields
      connection.expects(:delete_multiple_objects).with(
        'my_bucket', ['obj_key'], { :quiet => true }
      ).returns(resp_ok)
      cloud_io.delete('obj_key')
    end

    it 'accepts multiple keys' do
      cloud_io.expects(:with_retries).with('DELETE Multiple Objects').yields
      connection.expects(:delete_multiple_objects).with(
        'my_bucket', ['obj_key_a', 'obj_key_b'], { :quiet => true }
      ).returns(resp_ok)

      objects = ['obj_key_a', 'obj_key_b']
      expect do
        cloud_io.delete(objects)
      end.not_to change { objects }
    end

    it 'does nothing if empty array passed' do
      connection.expects(:delete_multiple_objects).never
      cloud_io.delete([])
    end

    context 'with more than 1000 objects' do
      let(:keys_1k) { 1000.times.map { 'key' } }
      let(:keys_10) { 10.times.map { 'key' } }
      let(:keys_all) { keys_1k + keys_10 }

      before do
        cloud_io.expects(:with_retries).twice.with('DELETE Multiple Objects').yields
      end

      it 'deletes 1000 objects per request' do
        connection.expects(:delete_multiple_objects).with(
          'my_bucket', keys_1k, { :quiet => true }
        ).returns(resp_ok)
        connection.expects(:delete_multiple_objects).with(
          'my_bucket', keys_10, { :quiet => true }
        ).returns(resp_ok)

        expect do
          cloud_io.delete(keys_all)
        end.not_to change { keys_all }
      end

      it 'prevents mutation of options to delete_multiple_objects' do
        connection.expects(:delete_multiple_objects).with do |bucket, keys, opts|
          bucket == 'my_bucket' && keys == keys_1k && opts.delete(:quiet)
        end.returns(resp_ok)
        connection.expects(:delete_multiple_objects).with(
          'my_bucket', keys_10, { :quiet => true }
        ).returns(resp_ok)

        expect do
          cloud_io.delete(keys_all)
        end.not_to change { keys_all }

      end

    end

    it 'retries on raised errors' do
      connection.expects(:delete_multiple_objects).twice.
          with('my_bucket', ['obj_key'], { :quiet => true }).
          raises('error').then.returns(resp_ok)
      cloud_io.delete('obj_key')
    end

    it 'retries on returned errors' do
      connection.expects(:delete_multiple_objects).twice.
          with('my_bucket', ['obj_key'], { :quiet => true }).
          returns(resp_bad).then.returns(resp_ok)
      cloud_io.delete('obj_key')
    end

    it 'fails after retries exceeded' do
      connection.expects(:delete_multiple_objects).twice.
          with('my_bucket', ['obj_key'], { :quiet => true }).
          raises('error message').then.returns(resp_bad)

      expect do
        cloud_io.delete('obj_key')
      end.to raise_error(CloudIO::Error) {|err|
        expect( err.message ).to eq(
          "CloudIO::Error: Max Retries (1) Exceeded!\n" +
          "  Operation: DELETE Multiple Objects\n" +
          "  Be sure to check the log messages for each retry attempt.\n" +
          "--- Wrapped Exception ---\n" +
          "CloudIO::S3::Error: The server returned the following:\n" +
          "  Failed to delete: obj_key\n" +
          "  Reason: InternalError: We encountered an internal error. " +
            "Please try again."
        )
      }
      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "CloudIO::Error: Retry #1 of 1\n" +
        "  Operation: DELETE Multiple Objects\n" +
        "--- Wrapped Exception ---\n" +
        "RuntimeError: error message"
      )
    end

  end # describe '#delete'

  describe '#connection' do
    specify 'using AWS access keys' do
      Fog::Storage.expects(:new).once.with(
        :provider               => 'AWS',
        :aws_access_key_id      => 'my_access_key_id',
        :aws_secret_access_key  => 'my_secret_access_key',
        :region                 => 'my_region'
      ).returns(connection)
      connection.expects(:sync_clock).once

      cloud_io = CloudIO::S3.new(
        :access_key_id      => 'my_access_key_id',
        :secret_access_key  => 'my_secret_access_key',
        :region             => 'my_region'
      )

      expect( cloud_io.send(:connection) ).to be connection
      expect( cloud_io.send(:connection) ).to be connection
    end

    specify 'using AWS IAM profile' do
      Fog::Storage.expects(:new).once.with(
        :provider               => 'AWS',
        :use_iam_profile        => true,
        :region                 => 'my_region'
      ).returns(connection)
      connection.expects(:sync_clock).once

      cloud_io = CloudIO::S3.new(
        :use_iam_profile  => true,
        :region           => 'my_region'
      )

      expect( cloud_io.send(:connection) ).to be connection
      expect( cloud_io.send(:connection) ).to be connection
    end

    it 'passes along fog_options' do
      Fog::Storage.expects(:new).with({
          :provider => 'AWS',
          :region => nil,
          :aws_access_key_id => 'my_key',
          :aws_secret_access_key => 'my_secret',
          :connection_options => { :opt_key => 'opt_value' },
          :my_key => 'my_value'
      }).returns(stub(:sync_clock))
      CloudIO::S3.new(
        :access_key_id => 'my_key',
        :secret_access_key => 'my_secret',
        :fog_options => {
          :connection_options => { :opt_key => 'opt_value' },
          :my_key => 'my_value'
        }
      ).send(:connection)
    end
  end # describe '#connection'

  describe '#put_object' do
    let(:cloud_io) {
      CloudIO::S3.new(
        :bucket => 'my_bucket',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }
    let(:file) { mock }

    before do
      cloud_io.stubs(:connection).returns(connection)
      md5_file = mock
      Digest::MD5.expects(:file).with('/src/file').returns(md5_file)
      md5_file.expects(:digest).returns(:md5_digest)
      Base64.expects(:encode64).with(:md5_digest).returns("encoded_digest\n")
    end

    it 'calls put_object with Content-MD5 header' do
      File.expects(:open).with('/src/file', 'r').yields(file)
      connection.expects(:put_object).
        with('my_bucket', 'dest/file', file, { 'Content-MD5' => 'encoded_digest' })
      cloud_io.send(:put_object, '/src/file', 'dest/file')
    end

    it 'fails after retries' do
      File.expects(:open).twice.with('/src/file', 'r').yields(file)
      connection.expects(:put_object).twice.
        with('my_bucket', 'dest/file', file, { 'Content-MD5' => 'encoded_digest' }).
        raises('error1').then.raises('error2')

      expect do
        cloud_io.send(:put_object, '/src/file', 'dest/file')
      end.to raise_error(CloudIO::Error) {|err|
        expect( err.message ).to eq(
          "CloudIO::Error: Max Retries (1) Exceeded!\n" +
          "  Operation: PUT 'my_bucket/dest/file'\n" +
          "  Be sure to check the log messages for each retry attempt.\n" +
          "--- Wrapped Exception ---\n" +
          "RuntimeError: error2"
        )
      }
      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "CloudIO::Error: Retry #1 of 1\n" +
        "  Operation: PUT 'my_bucket/dest/file'\n" +
        "--- Wrapped Exception ---\n" +
        "RuntimeError: error1"
      )
    end

    context 'with #encryption and #storage_class set' do
      let(:cloud_io) {
        CloudIO::S3.new(
          :bucket => 'my_bucket',
          :encryption => :aes256,
          :storage_class => :reduced_redundancy,
          :max_retries => 1,
          :retry_waitsec => 0
        )
      }

      it 'sets headers for encryption and storage_class' do
        File.expects(:open).with('/src/file', 'r').yields(file)
        connection.expects(:put_object).with(
          'my_bucket', 'dest/file', file,
          { 'Content-MD5' => 'encoded_digest',
            'x-amz-server-side-encryption' => 'AES256',
            'x-amz-storage-class' => 'REDUCED_REDUNDANCY' }
        )
        cloud_io.send(:put_object, '/src/file', 'dest/file')
      end
    end
  end # describe '#put_object'

  describe '#initiate_multipart' do
    let(:cloud_io) {
      CloudIO::S3.new(
        :bucket => 'my_bucket',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }
    let(:response) { stub(:body => { 'UploadId' => 1234 }) }

    before do
      cloud_io.stubs(:connection).returns(connection)
      Logger.expects(:info).with("  Initiate Multipart 'my_bucket/dest/file'")
    end

    it 'initiates multipart upload with retries' do
      cloud_io.expects(:with_retries).
          with("POST 'my_bucket/dest/file' (Initiate)").yields
      connection.expects(:initiate_multipart_upload).
          with('my_bucket', 'dest/file', {}).returns(response)

      expect( cloud_io.send(:initiate_multipart, 'dest/file') ).to be 1234
    end

    context 'with #encryption and #storage_class set' do
      let(:cloud_io) {
        CloudIO::S3.new(
          :bucket => 'my_bucket',
          :encryption => :aes256,
          :storage_class => :reduced_redundancy,
          :max_retries => 1,
          :retry_waitsec => 0
        )
      }

      it 'sets headers for encryption and storage_class' do
        connection.expects(:initiate_multipart_upload).with(
          'my_bucket', 'dest/file',
          { 'x-amz-server-side-encryption' => 'AES256',
            'x-amz-storage-class' => 'REDUCED_REDUNDANCY' }
        ).returns(response)
        expect( cloud_io.send(:initiate_multipart, 'dest/file') ).to be 1234
      end
    end

  end # describe '#initiate_multipart'

  describe '#upload_parts' do
    let(:cloud_io) {
      CloudIO::S3.new(
        :bucket => 'my_bucket',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }
    let(:chunk_bytes) { 1024**2 * 5 }
    let(:file_size) { chunk_bytes + 250 }
    let(:chunk_a) { 'a' * chunk_bytes }
    let(:encoded_digest_a) { 'ebKBBg0ze5srhMzzkK3PdA==' }
    let(:chunk_a_resp) { stub(:headers => { 'ETag' => 'chunk_a_etag' }) }
    let(:chunk_b) { 'b' * 250 }
    let(:encoded_digest_b) { 'OCttLDka1ocamHgkHvZMyQ==' }
    let(:chunk_b_resp) { stub(:headers => { 'ETag' => 'chunk_b_etag' }) }
    let(:file) { StringIO.new(chunk_a + chunk_b) }

    before do
      cloud_io.stubs(:connection).returns(connection)
    end

    it 'uploads chunks with Content-MD5' do
      File.expects(:open).with('/src/file', 'r').yields(file)
      StringIO.stubs(:new).with(chunk_a).returns(:stringio_a)
      StringIO.stubs(:new).with(chunk_b).returns(:stringio_b)

      cloud_io.expects(:with_retries).with(
        "PUT 'my_bucket/dest/file' Part #1"
      ).yields

      connection.expects(:upload_part).with(
        'my_bucket', 'dest/file', 1234, 1, :stringio_a,
        { 'Content-MD5' => encoded_digest_a }
      ).returns(chunk_a_resp)

      cloud_io.expects(:with_retries).with(
        "PUT 'my_bucket/dest/file' Part #2"
      ).yields

      connection.expects(:upload_part).with(
        'my_bucket', 'dest/file', 1234, 2, :stringio_b,
        { 'Content-MD5' => encoded_digest_b }
      ).returns(chunk_b_resp)

      expect(
        cloud_io.send(:upload_parts,
                      '/src/file', 'dest/file', 1234, chunk_bytes, file_size)
      ).to eq ['chunk_a_etag', 'chunk_b_etag']

      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "  Uploading 2 Parts...\n" +
        "  ...90% Complete..."
      )
    end

    it 'logs progress' do
      chunk_bytes = 1024**2 * 1
      file_size = chunk_bytes * 100
      file = StringIO.new('x' * file_size)
      File.expects(:open).with('/src/file', 'r').yields(file)
      Digest::MD5.stubs(:digest)
      Base64.stubs(:encode64).returns('')
      connection.stubs(:upload_part).returns(stub(:headers => {}))

      cloud_io.send(:upload_parts,
                    '/src/file', 'dest/file', 1234, chunk_bytes, file_size)
      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "  Uploading 100 Parts...\n" +
        "  ...10% Complete...\n" +
        "  ...20% Complete...\n" +
        "  ...30% Complete...\n" +
        "  ...40% Complete...\n" +
        "  ...50% Complete...\n" +
        "  ...60% Complete...\n" +
        "  ...70% Complete...\n" +
        "  ...80% Complete...\n" +
        "  ...90% Complete..."
      )
    end

  end # describe '#upload_parts'

  describe '#complete_multipart' do
    let(:cloud_io) {
      CloudIO::S3.new(
        :bucket => 'my_bucket',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }
    let(:resp_ok) {
      stub(:body => {
        'Location' => 'http://my_bucket.s3.amazonaws.com/dest/file',
        'Bucket' => 'my_bucket',
        'Key' => 'dest/file',
        'ETag' => '"some-etag"'
      })
    }
    let(:resp_bad) {
      stub(:body => {
        'Code' => 'InternalError',
        'Message' => 'We encountered an internal error. Please try again.'
      })
    }

    before do
      cloud_io.stubs(:connection).returns(connection)
    end

    it 'retries on raised errors' do
      connection.expects(:complete_multipart_upload).twice.
          with('my_bucket', 'dest/file', 1234, [:parts]).
          raises('error').then.returns(resp_ok)
      cloud_io.send(:complete_multipart, 'dest/file', 1234, [:parts])
    end

    it 'retries on returned errors' do
      connection.expects(:complete_multipart_upload).twice.
          with('my_bucket', 'dest/file', 1234, [:parts]).
          returns(resp_bad).then.returns(resp_ok)
      cloud_io.send(:complete_multipart, 'dest/file', 1234, [:parts])
    end

    it 'fails after retries exceeded' do
      connection.expects(:complete_multipart_upload).twice.
          with('my_bucket', 'dest/file', 1234, [:parts]).
          raises('error message').then.returns(resp_bad)

      expect do
        cloud_io.send(:complete_multipart, 'dest/file', 1234, [:parts])
      end.to raise_error(CloudIO::Error) {|err|
        expect( err.message ).to eq(
          "CloudIO::Error: Max Retries (1) Exceeded!\n" +
          "  Operation: POST 'my_bucket/dest/file' (Complete)\n" +
          "  Be sure to check the log messages for each retry attempt.\n" +
          "--- Wrapped Exception ---\n" +
          "CloudIO::S3::Error: The server returned the following error:\n" +
          "  InternalError: We encountered an internal error. Please try again."
        )
      }
      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "  Complete Multipart 'my_bucket/dest/file'\n" +
        "CloudIO::Error: Retry #1 of 1\n" +
        "  Operation: POST 'my_bucket/dest/file' (Complete)\n" +
        "--- Wrapped Exception ---\n" +
        "RuntimeError: error message"
      )
    end
  end # describe '#complete_multipart'

  describe '#headers' do
    let(:cloud_io) { CloudIO::S3.new }

    it 'returns empty headers by default' do
      cloud_io.stubs(:encryption).returns(nil)
      cloud_io.stubs(:storage_class).returns(nil)
      cloud_io.send(:headers).should == {}
    end

    it 'returns headers for server-side encryption' do
      cloud_io.stubs(:storage_class).returns(nil)
      ['aes256', :aes256].each do |arg|
        cloud_io.stubs(:encryption).returns(arg)
        cloud_io.send(:headers).should ==
            { 'x-amz-server-side-encryption' => 'AES256' }
      end
    end

    it 'returns headers for reduced redundancy storage' do
      cloud_io.stubs(:encryption).returns(nil)
      ['reduced_redundancy', :reduced_redundancy].each do |arg|
        cloud_io.stubs(:storage_class).returns(arg)
        cloud_io.send(:headers).should ==
            { 'x-amz-storage-class' => 'REDUCED_REDUNDANCY' }
      end
    end

    it 'returns headers for both' do
      cloud_io.stubs(:encryption).returns(:aes256)
      cloud_io.stubs(:storage_class).returns(:reduced_redundancy)
      cloud_io.send(:headers).should ==
          { 'x-amz-server-side-encryption' => 'AES256',
            'x-amz-storage-class' => 'REDUCED_REDUNDANCY' }
    end

    it 'returns empty headers for empty values' do
      cloud_io.stubs(:encryption).returns('')
      cloud_io.stubs(:storage_class).returns('')
      cloud_io.send(:headers).should == {}
    end
  end # describe '#headers

  describe 'Object' do
    let(:cloud_io) { CloudIO::S3.new }
    let(:obj_data) {
      { 'Key' => 'obj_key', 'ETag' => 'obj_etag', 'StorageClass' => 'STANDARD' }
    }
    let(:object) { CloudIO::S3::Object.new(cloud_io, obj_data) }

    describe '#initialize' do
      it 'creates Object from data' do
        expect( object.key ).to eq 'obj_key'
        expect( object.etag ).to eq 'obj_etag'
        expect( object.storage_class ).to eq 'STANDARD'
      end
    end

    describe '#encryption' do
      it 'returns the algorithm used for server-side encryption' do
        cloud_io.expects(:head_object).once.with(object).returns(
          stub(:headers => { 'x-amz-server-side-encryption' => 'AES256' })
        )
        expect( object.encryption ).to eq 'AES256'
        expect( object.encryption ).to eq 'AES256'
      end

      it 'returns nil if SSE was not used' do
        cloud_io.expects(:head_object).once.with(object).
            returns(stub(:headers => {}))
        expect( object.encryption ).to be_nil
        expect( object.encryption ).to be_nil
      end
    end # describe '#encryption'

  end # describe 'Object'

end
end
