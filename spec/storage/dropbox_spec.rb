# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::Dropbox do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::Dropbox.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Storage::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( storage.storage_id    ).to be_nil
      expect( storage.keep          ).to be_nil
      expect( storage.api_key       ).to be_nil
      expect( storage.api_secret    ).to be_nil
      expect( storage.chunk_size    ).to be 4
      expect( storage.max_retries   ).to be 10
      expect( storage.retry_waitsec ).to be 30
      expect( storage.path          ).to eq 'backups'
    end

    it 'configures the storage' do
      storage = Storage::Dropbox.new(model, :my_id) do |db|
        db.keep           = 2
        db.api_key        = 'my_api_key'
        db.api_secret     = 'my_api_secret'
        db.chunk_size     = 10
        db.max_retries    = 15
        db.retry_waitsec  = 45
        db.path           = 'my/path'
      end

      expect( storage.storage_id    ).to eq 'my_id'
      expect( storage.keep          ).to be 2
      expect( storage.api_key       ).to eq 'my_api_key'
      expect( storage.api_secret    ).to eq 'my_api_secret'
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

  describe '#connection' do
    let(:session) { mock }
    let(:client)  { mock }

    context 'when a cached session exists' do
      before do
        storage.stubs(:cached_session).returns(session)
        storage.expects(:create_write_and_return_new_session!).never
        DropboxClient.expects(:new).once.with(session, :app_folder).returns(client)
      end

      it 'uses the cached session to create the client' do
        storage.send(:connection).should be(client)
      end

      it 'returns an already existing client' do
        storage.send(:connection).should be(client)
        storage.send(:connection).should be(client)
      end
    end

    context 'when a cached session does not exist' do
      before do
        storage.stubs(:cached_session).returns(false)
        Logger.expects(:info).with('Creating a new session!')
        storage.expects(:create_write_and_return_new_session!).returns(session)
        DropboxClient.expects(:new).once.with(session, :app_folder).returns(client)
      end

      it 'creates a new session and returns the client' do
        storage.send(:connection).should be(client)
      end

      it 'returns an already existing client' do
        storage.send(:connection).should be(client)
        storage.send(:connection).should be(client)
      end
    end

    context 'when an error is raised creating a client for the session' do
      it 'raises an error' do
        storage.stubs(:cached_session).returns(true)
        DropboxClient.expects(:new).raises('error')

        expect do
          storage.send(:connection)
        end.to raise_error(Storage::Dropbox::Error) {|err|
          expect( err.message ).to eq(
            "Storage::Dropbox::Error: Authorization Failed\n" +
            "--- Wrapped Exception ---\n" +
            "RuntimeError: error"
          )
        }
      end
    end

  end # describe '#connection'

  describe '#cached_session' do
    let(:session) { mock }
    let(:cached_file) { File.join(Config.cache_path, 'my_api_keymy_api_secret') }

    before do
      storage.api_key = 'my_api_key'
      storage.api_secret = 'my_api_secret'
    end

    it 'returns the cached session if one exists' do
      File.expects(:exist?).with(cached_file).returns(true)
      File.expects(:read).with(cached_file).returns('yaml_data')
      DropboxSession.expects(:deserialize).with('yaml_data').returns(session)
      Backup::Logger.expects(:info).with('Session data loaded from cache!')

      storage.send(:cached_session).should be(session)
    end

    it 'returns false when no cached session file exists' do
      File.expects(:exist?).with(cached_file).returns(false)
      expect( storage.send(:cached_session) ).to be false
    end

    context 'when errors occur loading the session' do
      it 'logs a warning and return false' do
        File.expects(:exist?).with(cached_file).returns(true)
        File.expects(:read).with(cached_file).returns('yaml_data')
        DropboxSession.expects(:deserialize).with('yaml_data').
            raises('error message')
        Logger.expects(:warn).with do |err|
          expect( err ).to be_an_instance_of(Storage::Dropbox::Error)
          expect( err.message ).to match(
            "Could not read session data from cache.\n" +
            "  Cache data might be corrupt."
          )
          expect( err.message ).to match('RuntimeError: error message')
        end

        expect do
          expect( storage.send(:cached_session) ).to be false
        end.not_to raise_error
      end
    end
  end # describe '#cached_session'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
    let(:file) { mock }
    let(:uploader) { mock }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.stubs(:connection).returns(connection)
      file.stubs(:stat).returns(stub(:size => 6_291_456))
      uploader.stubs(:total_size).returns(6_291_456)
      uploader.stubs(:offset).returns(
        0, 2_097_152, 4_194_304, 6_291_456,
        0, 2_097_152, 4_194_304, 6_291_456
      )
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
      dest = File.join(remote_path, 'test_trigger.tar-aa')

      Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
      File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
      connection.expects(:get_chunked_uploader).in_sequence(s).
          with(file, 6_291_456).returns(uploader)
      uploader.expects(:upload).in_sequence(s).times(3).with(2_097_152)
      uploader.expects(:finish).in_sequence(s).with(dest)

      # second file
      src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
      dest = File.join(remote_path, 'test_trigger.tar-ab')

      Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
      File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
      connection.expects(:get_chunked_uploader).in_sequence(s).
          with(file, 6_291_456).returns(uploader)
      uploader.expects(:upload).in_sequence(s).times(3).with(2_097_152)
      uploader.expects(:finish).in_sequence(s).with(dest)

      storage.send(:transfer!)
    end

    it 'retries on errors' do
      storage.max_retries = 1
      storage.package.stubs(:filenames).returns(['test_trigger.tar'])

      src = File.join(Config.tmp_path, 'test_trigger.tar')
      dest = File.join(remote_path, 'test_trigger.tar')

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
      connection.expects(:get_chunked_uploader).in_sequence(s).
          with(file, 6_291_456).returns(uploader)

      uploader.expects(:upload).in_sequence(s).raises('chunk failed')

      storage.expects(:sleep).in_sequence(s).with(30)

      uploader.expects(:upload).in_sequence(s).times(3).with(2_097_152)

      uploader.expects(:finish).in_sequence(s).with(dest).raises('finish failed')

      storage.expects(:sleep).in_sequence(s).with(30)

      uploader.expects(:finish).in_sequence(s).with(dest)

      storage.send(:transfer!)
    end

    it 'fails when retries are exceeded' do
      storage.max_retries = 2
      storage.package.stubs(:filenames).returns(['test_trigger.tar'])

      src = File.join(Config.tmp_path, 'test_trigger.tar')
      dest = File.join(remote_path, 'test_trigger.tar')

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
      connection.expects(:get_chunked_uploader).in_sequence(s).
          with(file, 6_291_456).returns(uploader)

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
    let(:connection) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
    let(:package) {
      stub( # loaded from YAML storage file
        :trigger    => 'test_trigger',
        :time       => timestamp
      )
    }

    before do
      Timecop.freeze
      storage.stubs(:connection).returns(connection)
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'removes the given package from the remote' do
      Logger.expects(:info).in_sequence(s).
          with("Removing backup package dated #{ timestamp }...")

      connection.expects(:file_delete).with(remote_path)

      storage.send(:remove!, package)
    end

  end # describe '#remove!'

  describe '#write_cache!' do
    let(:session) { mock }
    let(:cached_file) { File.join(Config.cache_path, 'my_api_keymy_api_secret') }
    let(:file) { mock }

    before do
      storage.api_key = 'my_api_key'
      storage.api_secret = 'my_api_secret'
      session.stubs(:serialize).returns('serialized_data')
    end

    it 'should write a serialized session to file' do
      FileUtils.expects(:mkdir_p).with(Config.cache_path)

      File.expects(:open).with(cached_file, 'w').yields(file)
      file.expects(:write).with('serialized_data')

      storage.send(:write_cache!, session)
    end
  end # describe '#write_cache!'

  describe '#create_write_and_return_new_session!' do
    let(:session)   { mock }
    let(:template)  { mock }
    let(:cached_file) { File.join(Config.cache_path, 'my_api_keymy_api_secret') }

    before do
      storage.api_key = 'my_api_key'
      storage.api_secret = 'my_api_secret'

      DropboxSession.expects(:new).in_sequence(s).
          with('my_api_key', 'my_api_secret').returns(session)
      session.expects(:get_request_token).in_sequence(s)
      Template.expects(:new).in_sequence(s).with(
        { :session => session, :cached_file => cached_file }
      ).returns(template)
      template.expects(:render).in_sequence(s).with(
        'storage/dropbox/authorization_url.erb'
      )
      Timeout.expects(:timeout).in_sequence(s).with(180).yields
      STDIN.expects(:gets).in_sequence(s)
    end

    context 'when session is authenticated' do
      before do
        session.expects(:get_access_token).in_sequence(s)
      end

      it 'caches and returns the new session' do
        template.expects(:render).in_sequence(s).with(
          'storage/dropbox/authorized.erb'
        )
        storage.expects(:write_cache!).in_sequence(s).with(session)
        template.expects(:render).in_sequence(s).with(
          'storage/dropbox/cache_file_written.erb'
        )

        storage.send(:create_write_and_return_new_session!).should be(session)
      end
    end

    context 'when session is not authenticated' do
      before do
        session.expects(:get_access_token).in_sequence(s).raises('error message')
      end

      it 'raises an error' do
        template.expects(:render).with('storage/dropbox/authorized.erb').never
        storage.expects(:write_cache!).never
        template.expects(:render).with('storage/dropbox/cache_file_written.erb').never

        expect do
          storage.send(:create_write_and_return_new_session!)
        end.to raise_error(Storage::Dropbox::Error) {|err|
          expect( err.message ).to match(
            "Could not create or authenticate a new session"
          )
          expect( err.message ).to match('RuntimeError: error message')
        }
      end
    end
  end # describe '#create_write_and_return_new_session!' do

  describe 'deprecations' do
    after do
      Storage::Dropbox.clear_defaults!
    end

    describe '#email' do
      before do
        Logger.expects(:warn).with do |err|
          expect( err.message ).to match(
            "Dropbox#email has been deprecated as of backup v.3.0.17"
          )
        end
      end

      context 'when set directly' do
        it 'should issue a deprecation warning' do
          Storage::Dropbox.new(model) do |storage|
            storage.email = 'foo'
          end
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning' do
          Storage::Dropbox.defaults do |storage|
            storage.email = 'foo'
          end
          Storage::Dropbox.new(model)
        end
      end
    end

    describe '#password' do
      before do
        Logger.expects(:warn).with do |err|
          expect( err.message ).to match(
            "Dropbox#password has been deprecated as of backup v.3.0.17"
          )
        end
      end

      context 'when set directly' do
        it 'should issue a deprecation warning' do
          Storage::Dropbox.new(model) do |storage|
            storage.password = 'foo'
          end
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning' do
          Storage::Dropbox.defaults do |storage|
            storage.password = 'foo'
          end
          Storage::Dropbox.new(model)
        end
      end
    end

    describe '#timeout' do
      before do
        Logger.expects(:warn).with do |err|
          expect( err.message ).to match(
            "Dropbox#timeout has been deprecated as of backup v.3.0.21"
          )
        end
      end

      context 'when set directly' do
        it 'should issue a deprecation warning' do
          Storage::Dropbox.new(model) do |storage|
            storage.timeout = 'foo'
          end
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning' do
          Storage::Dropbox.defaults do |storage|
            storage.timeout = 'foo'
          end
          Storage::Dropbox.new(model)
        end
      end
    end

    describe '#chunk_retries' do
      before do
        Backup::Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Backup::Configuration::Error
          expect( err.message ).to match(/Use #max_retries instead/)
        }
      end

      specify 'set as a default' do
        Storage::Dropbox.defaults do |db|
          db.chunk_retries = 15
        end
        storage = Storage::Dropbox.new(model)
        expect( storage.max_retries ).to be 15
      end

      specify 'set directly' do
        storage = Storage::Dropbox.new(model) do |db|
          db.chunk_retries = 15
        end
        expect( storage.max_retries ).to be 15
      end
    end
  end # describe 'deprecations'

end
end
