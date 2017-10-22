require "spec_helper"

module Backup
  describe Storage::Dropbox do
    let(:model) { Model.new(:test_trigger, 'test label') }
    let(:storage) { Storage::Dropbox.new(model) }
    let(:s) { sequence '' }

    it_behaves_like 'a class that includes Config::Helpers'
    it_behaves_like 'a subclass of Storage::Base'
    it_behaves_like 'a storage that cycles'

    describe '#initialize' do
      it 'provides default values' do
        expect( storage.storage_id    ).to be_nil
        expect( storage.api_token    ).to be_nil
        expect( storage.chunk_size    ).to be 4
        expect( storage.max_retries   ).to be 10
        expect( storage.retry_waitsec ).to be 30
        expect( storage.path          ).to eq 'backups'
      end

      it 'configures the storage' do
        storage = Storage::Dropbox.new(model, :my_id) do |db|
          db.api_token     = 'my_api_token'
          db.chunk_size     = 10
          db.max_retries    = 15
          db.retry_waitsec  = 45
          db.path           = 'my/path'
        end

        expect( storage.storage_id    ).to eq 'my_id'
        expect( storage.api_token    ).to eq 'my_api_token'
        expect( storage.chunk_size    ).to eq 10
        expect( storage.max_retries   ).to eq 15
        expect( storage.retry_waitsec ).to eq 45
        expect( storage.path          ).to eq 'my/path'
      end

      it 'strips leading path separator' do
        storage = Storage::Dropbox.new(model) do |s3|
          s3.path = '/this/path'
        end
        expect( storage.path ).to eq 'this/path'
      end
    end # describe '#initialize'

    describe '#client' do
      let(:client)  { mock }

      context 'when client exists' do
        before do
          DropboxApi::Client.expects(:new).once.with(nil).returns(client)
        end

        it 'returns an already existing client' do
          storage.send(:client).should be(client)
          storage.send(:client).should be(client)
        end
      end

      context 'when an error is raised creating a client for the session' do
        it 'raises an error' do
          DropboxApi::Client.expects(:new).raises('error')

          expect do
            storage.send(:client)
          end.to raise_error(Storage::Dropbox::Error) {|err|
            expect( err.message ).to eq(
              "Storage::Dropbox::Error: Authorization Failed\n" +
              "--- Wrapped Exception ---\n" +
              "RuntimeError: error"
            )
          }
        end
      end
    end # describe '#client'


    describe '#transfer!' do
      let(:client) { mock }
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
      let(:file) { mock }
      let(:uploader) { mock }

      before do
        Timecop.freeze
        storage.package.time = timestamp
        storage.stubs(:client).returns(client)
        file.stubs(:stat).returns(stub(size: 6_291_456))
        storage.path = 'my/path'
        storage.chunk_size = 2
      end

      after { Timecop.return }

      it 'transfers the package files' do
        storage.package.stubs(:filenames).returns(
          ['test_trigger.tar-aa', 'test_trigger.tar-ab']
        )

        # first file
        src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
        dest = File.join('/', remote_path, 'test_trigger.tar-aa')

        Storage::Dropbox::ChunkedUploader.expects(:new).with(client, file).returns(uploader)
        Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
        File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
        uploader.expects(:upload).in_sequence(s).with(2_097_152)
        uploader.expects(:finish).in_sequence(s).with(dest)

        # # second file
        src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
        dest = File.join('/', remote_path, 'test_trigger.tar-ab')

        Storage::Dropbox::ChunkedUploader.expects(:new).with(client, file).returns(uploader)
        Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
        File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
        uploader.expects(:upload).in_sequence(s)
        uploader.expects(:finish).in_sequence(s).with(dest)

        storage.send(:transfer!)
      end

      it 'retries on errors' do
        storage.max_retries = 1
        storage.package.stubs(:filenames).returns(['test_trigger.tar'])

        src = File.join(Config.tmp_path, 'test_trigger.tar')
        dest = File.join('/', remote_path, 'test_trigger.tar')

        @logger_calls = 0
        Logger.expects(:info).times(3).with do |arg|
          @logger_calls += 1
          case @logger_calls
          when 1
            expect( arg ).to eq "Storing '#{ dest }'..."
          when 2
            expect( arg ).to be_an_instance_of Storage::Dropbox::Error
            expect( arg.message ).to match(
              "Storage::Dropbox::Error: Retry #1 of 1."
            )
            expect( arg.message ).to match('RuntimeError: chunk failed')
          when 3
            expect( arg ).to be_an_instance_of Storage::Dropbox::Error
            expect( arg.message ).to match(
              "Storage::Dropbox::Error: Retry #1 of 1."
            )
            expect( arg.message ).to match('RuntimeError: finish failed')
          end
        end

        File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
        Storage::Dropbox::ChunkedUploader.expects(:new).in_sequence(s).
          with(client, file).returns(uploader)

        uploader.expects(:upload).in_sequence(s).raises('chunk failed')

        storage.expects(:sleep).in_sequence(s).with(30)

        uploader.expects(:upload).in_sequence(s).with(2_097_152)

        uploader.expects(:finish).in_sequence(s).with(dest).raises('finish failed')

        storage.expects(:sleep).in_sequence(s).with(30)

        uploader.expects(:finish).in_sequence(s).with(dest)

        storage.send(:transfer!)
      end

      it 'fails when retries are exceeded' do
        storage.max_retries = 2
        storage.package.stubs(:filenames).returns(['test_trigger.tar'])

        src = File.join(Config.tmp_path, 'test_trigger.tar')
        dest = File.join('/', remote_path, 'test_trigger.tar')

        @logger_calls = 0
        Logger.expects(:info).times(3).with do |arg|
          @logger_calls += 1
          case @logger_calls
          when 1
            expect( arg ).to eq "Storing '#{ dest }'..."
          when 2
            expect( arg ).to be_an_instance_of Storage::Dropbox::Error
            expect( arg.message ).to match(
              "Storage::Dropbox::Error: Retry #1 of 2."
            )
            expect( arg.message ).to match('RuntimeError: chunk failed')
          when 3
            expect( arg ).to be_an_instance_of Storage::Dropbox::Error
            expect( arg.message ).to match(
              "Storage::Dropbox::Error: Retry #2 of 2."
            )
            expect( arg.message ).to match('RuntimeError: chunk failed again')
          end
        end

        File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
        Storage::Dropbox::ChunkedUploader.expects(:new).in_sequence(s).
          with(client, file).returns(uploader)

        uploader.expects(:upload).in_sequence(s).raises('chunk failed')

        storage.expects(:sleep).in_sequence(s).with(30)

        uploader.expects(:upload).in_sequence(s).raises('chunk failed again')

        storage.expects(:sleep).in_sequence(s).with(30)

        uploader.expects(:upload).in_sequence(s).raises('strike three')

        uploader.expects(:finish).never

        expect do
          storage.send(:transfer!)
        end.to raise_error(Storage::Dropbox::Error) {|err|
          expect( err.message ).to match('Upload Failed!')
          expect( err.message ).to match('RuntimeError: strike three')
        }
      end

    end # describe '#transfer!'

    describe '#remove!' do
      let(:client) { mock }
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join('/my/path/test_trigger', timestamp) }
      let(:package) {
        stub( # loaded from YAML storage file
             :trigger    => 'test_trigger',
             :time       => timestamp
            )
      }

      before do
        Timecop.freeze
        storage.stubs(:client).returns(client)
        storage.path = 'my/path'
      end

      after { Timecop.return }

      it 'removes the given package from the remote' do
        Logger.expects(:info).in_sequence(s).
          with("Removing backup package dated #{ timestamp }...")

        client.expects(:delete).with(remote_path)

        storage.send(:remove!, package)
      end

    end # describe '#remove!'
  end
end
