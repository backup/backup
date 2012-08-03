# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::Dropbox do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::Dropbox.new(model) do |db|
      db.api_key      = 'my_api_key'
      db.api_secret   = 'my_api_secret'
      db.keep         = 5
    end
  end

  it 'should be a subclass of Storage::Base' do
    Backup::Storage::Dropbox.
      superclass.should == Backup::Storage::Base
  end

  describe '#initialize' do
    after { Backup::Storage::Dropbox.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Storage::Dropbox.any_instance.expects(:load_defaults!)
      storage
    end

    it 'should pass the model reference to Base' do
      storage.instance_variable_get(:@model).should == model
    end

    it 'should pass the storage_id to Base' do
      storage = Backup::Storage::Dropbox.new(model, 'my_storage_id')
      storage.storage_id.should == 'my_storage_id'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        storage.api_key.should      == 'my_api_key'
        storage.api_secret.should   == 'my_api_secret'
        storage.access_type.should  == :app_folder
        storage.path.should         == 'backups'

        storage.storage_id.should be_nil
        storage.keep.should       == 5
      end

      it 'should use default values if none are given' do
        storage = Backup::Storage::Dropbox.new(model)
        storage.api_key.should      be_nil
        storage.api_secret.should   be_nil
        storage.access_type.should  == :app_folder
        storage.path.should         == 'backups'

        storage.storage_id.should be_nil
        storage.keep.should       be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Storage::Dropbox.defaults do |s|
          s.api_key      = 'some_api_key'
          s.api_secret   = 'some_api_secret'
          s.access_type  = 'some_access_type'
          s.path         = 'some_path'
          s.keep         = 15
        end
      end

      it 'should use pre-configured defaults' do
        storage = Backup::Storage::Dropbox.new(model)

        storage.api_key.should      == 'some_api_key'
        storage.api_secret.should   == 'some_api_secret'
        storage.access_type.should  == 'some_access_type'
        storage.path.should         == 'some_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 15
      end

      it 'should override pre-configured defaults' do
        storage = Backup::Storage::Dropbox.new(model) do |s|
          s.api_key      = 'new_api_key'
          s.api_secret   = 'new_api_secret'
          s.access_type  = 'new_access_type'
          s.path         = 'new_path'
          s.keep         = 10
        end

        storage.api_key.should      == 'new_api_key'
        storage.api_secret.should   == 'new_api_secret'
        storage.access_type.should  == 'new_access_type'
        storage.path.should         == 'new_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 10
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#connection' do
    let(:session)     { mock }
    let(:client)      { mock }
    let(:s)           { sequence '' }

    context 'when a cached session exists' do
      before do
        storage.expects(:cached_session).in_sequence(s).returns(session)
        storage.expects(:create_write_and_return_new_session!).never
        DropboxClient.expects(:new).in_sequence(s).
            with(session, :app_folder).returns(client)
      end

      it 'should use the cached session to create the client' do
        storage.send(:connection).should be(client)
      end

      it 'should return an already existing client' do
        storage.send(:connection).should be(client)
        storage.send(:connection).should be(client)
      end
    end

    context 'when a cached session does not exist' do
      before do
        storage.expects(:cached_session).in_sequence(s).returns(false)
        Backup::Logger.expects(:message).in_sequence(s).with(
          'Creating a new session!'
        )
        storage.expects(:create_write_and_return_new_session!).in_sequence(s).
            returns(session)
        DropboxClient.expects(:new).in_sequence(s).
            with(session, :app_folder).returns(client)
      end

      it 'should create a new session and return the client' do
        storage.send(:connection).should be(client)
      end

      it 'should return an already existing client' do
        storage.send(:connection).should be(client)
        storage.send(:connection).should be(client)
      end
    end

    context 'when an error is raised creating a client for the session' do
      it 'should wrap and raise the error' do
        storage.stubs(:cached_session).returns(true)
        DropboxClient.expects(:new).raises('error')

        expect do
          storage.send(:connection)
        end.to raise_error {|err|
          err.should be_an_instance_of(
            Backup::Errors::Storage::Dropbox::ConnectionError
          )
          err.message.should ==
              'Storage::Dropbox::ConnectionError: RuntimeError: error'
        }
      end
    end

  end # describe '#connection'

  describe '#cached_session' do
    let(:session) { mock }

    context 'when a cached session file exists' do
      before do
        storage.expects(:cache_exists?).returns(true)
        storage.expects(:cached_file).returns('cached_file')
        File.expects(:read).with('cached_file').returns('yaml_data')
      end

      context 'when the cached session is successfully loaded' do
        it 'should return the sesssion' do
          DropboxSession.expects(:deserialize).with('yaml_data').
              returns(session)
          Backup::Logger.expects(:message).with(
            'Session data loaded from cache!'
          )

          storage.send(:cached_session).should be(session)
        end
      end

      context 'when errors occur loading the session' do
        it 'should log a warning and return false' do
          DropboxSession.expects(:deserialize).with('yaml_data').
              raises('error message')
          Backup::Logger.expects(:warn).with do |err|
            err.should be_an_instance_of(
              Backup::Errors::Storage::Dropbox::CacheError
            )
            err.message.should == 'Storage::Dropbox::CacheError: ' +
                "Could not read session data from cache.\n" +
                "  Cache data might be corrupt.\n" +
                "  Reason: RuntimeError\n" +
                "  error message"
          end

          expect do
            storage.send(:cached_session).should be_false
          end.not_to raise_error
        end
      end
    end

    context 'when a cached session file does not exist' do
      before { storage.stubs(:cache_exists?).returns(false) }
      it 'should return false' do
        storage.send(:cached_session).should be_false
      end
    end
  end

  describe '#transfer!' do
    let(:connection) { mock }
    let(:package) { mock }
    let(:file) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      storage.stubs(:storage_name).returns('Storage::Dropbox')
      storage.stubs(:local_path).returns('/local/path')
      storage.stubs(:connection).returns(connection)
    end

    it 'should transfer the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Dropbox started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa'."
      )
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'), 'r'
      ).yields(file)
      connection.expects(:put_file).in_sequence(s).with(
        File.join('remote/path', 'backup.tar.enc-aa'), file
      )
      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Dropbox started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab'."
      )
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab'), 'r'
      ).yields(file)
      connection.expects(:put_file).in_sequence(s).with(
        File.join('remote/path', 'backup.tar.enc-ab'), file
      )

      storage.send(:transfer!)
    end
  end # describe '#transfer!'

  describe '#remove!' do
    let(:package) { mock }
    let(:connection) { mock }
    let(:s) { sequence '' }

    before do
      storage.stubs(:storage_name).returns('Storage::Dropbox')
      storage.stubs(:connection).returns(connection)
    end

    it 'should remove the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      storage.expects(:transferred_files_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # after both yields
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Dropbox started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' from Dropbox.\n" +
        "Storage::Dropbox started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' from Dropbox."
      )
      connection.expects(:file_delete).in_sequence(s).with('remote/path')

      storage.send(:remove!, package)
    end
  end # describe '#remove!'

  describe '#cached_file' do
    it 'should return the path to the cache file' do
      storage.send(:cached_file).should ==
          File.join(Backup::Config.cache_path, 'my_api_keymy_api_secret')
    end
  end

  describe '#cache_exists?' do
    it 'should check if #cached_file exists' do
      storage.expects(:cached_file).returns('/path/to/cache_file')
      File.expects(:exist?).with('/path/to/cache_file')

      storage.send(:cache_exists?)
    end
  end

  describe '#write_cache!' do
    let(:session)     { mock }
    let(:cache_file)  { mock }

    it 'should write a serialized session to file' do
      storage.expects(:cached_file).returns('/path/to/cache_file')
      session.expects(:serialize).returns('serialized_data')

      File.expects(:open).with('/path/to/cache_file', 'w').yields(cache_file)
      cache_file.expects(:write).with('serialized_data')

      storage.send(:write_cache!, session)
    end
  end

  describe '#create_write_and_return_new_session!' do
    let(:session)   { mock }
    let(:template)  { mock }
    let(:s)         { sequence '' }

    before do
      storage.stubs(:cached_file).returns('/path/to/cache_file')

      DropboxSession.expects(:new).in_sequence(s).
          with('my_api_key', 'my_api_secret').returns(session)
      session.expects(:get_request_token).in_sequence(s)
      Backup::Template.expects(:new).in_sequence(s).with(
        {:session => session, :cached_file => '/path/to/cache_file'}
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

      it 'should cache and return the new session' do
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

      it 'should wrap and re-raise the error' do
        template.expects(:render).with('storage/dropbox/authorized.erb').never
        storage.expects(:write_cache!).never
        template.expects(:render).with('storage/dropbox/cache_file_written.erb').never

        expect do
          storage.send(:create_write_and_return_new_session!)
        end.to raise_error {|err|
          err.should be_an_instance_of(
            Backup::Errors::Storage::Dropbox::AuthenticationError
          )
          err.message.should == 'Storage::Dropbox::AuthenticationError: ' +
              "Could not create or authenticate a new session\n" +
              "  Reason: RuntimeError\n" +
              "  error message"
        }
      end
    end
  end

  describe 'deprecations' do
    after do
      Backup::Storage::Dropbox.clear_defaults!
    end

    describe '#email' do
      before do
        Backup::Logger.expects(:warn).with do |err|
          err.message.should match(
            "Dropbox#email has been deprecated as of backup v.3.0.17"
          )
        end
      end

      context 'when set directly' do
        it 'should issue a deprecation warning' do
          Backup::Storage::Dropbox.new(model) do |storage|
            storage.email = 'foo'
          end
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning' do
          Backup::Storage::Dropbox.defaults do |storage|
            storage.email = 'foo'
          end
          Backup::Storage::Dropbox.new(model)
        end
      end
    end

    describe '#password' do
      before do
        Backup::Logger.expects(:warn).with do |err|
          err.message.should match(
            "Dropbox#password has been deprecated as of backup v.3.0.17"
          )
        end
      end

      context 'when set directly' do
        it 'should issue a deprecation warning' do
          Backup::Storage::Dropbox.new(model) do |storage|
            storage.password = 'foo'
          end
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning' do
          Backup::Storage::Dropbox.defaults do |storage|
            storage.password = 'foo'
          end
          Backup::Storage::Dropbox.new(model)
        end
      end
    end

    describe '#timeout' do
      before do
        Backup::Logger.expects(:warn).with do |err|
          err.message.should match(
            "Dropbox#timeout has been deprecated as of backup v.3.0.21"
          )
        end
      end

      context 'when set directly' do
        it 'should issue a deprecation warning' do
          Backup::Storage::Dropbox.new(model) do |storage|
            storage.timeout = 'foo'
          end
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning' do
          Backup::Storage::Dropbox.defaults do |storage|
            storage.timeout = 'foo'
          end
          Backup::Storage::Dropbox.new(model)
        end
      end
    end
  end

end
