# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::Ninefold do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::Ninefold.new(model) do |nf|
      nf.storage_token    = 'my_token'
      nf.storage_secret   = 'my_secret'
      nf.keep             = 5
    end
  end

  describe '#initialize' do
    it 'should set the correct values' do
      storage.storage_token.should  == 'my_token'
      storage.storage_secret.should == 'my_secret'
      storage.path.should       == 'backups'

      storage.storage_id.should be_nil
      storage.keep.should       == 5
    end

    it 'should set a storage_id if given' do
      nf = Backup::Storage::Ninefold.new(model, 'my storage_id')
      nf.storage_id.should == 'my storage_id'
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Storage::Ninefold.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Storage::Ninefold.defaults do |nf|
          nf.storage_token    = 'some_token'
          nf.storage_secret   = 'some_secret'
          nf.path             = 'some_path'
          nf.keep             = 15
        end
        storage = Backup::Storage::Ninefold.new(model)
        storage.storage_token.should  == 'some_token'
        storage.storage_secret.should == 'some_secret'
        storage.path.should           == 'some_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 15
      end

      it 'should override the configured defaults' do
        Backup::Configuration::Storage::Ninefold.defaults do |nf|
          nf.storage_token    = 'old_token'
          nf.storage_secret   = 'old_secret'
          nf.path             = 'old_path'
          nf.keep             = 15
        end
        storage = Backup::Storage::Ninefold.new(model) do |nf|
          nf.storage_token    = 'new_token'
          nf.storage_secret   = 'new_secret'
          nf.path             = 'new_path'
          nf.keep             = 10
        end

        storage.storage_token.should  == 'new_token'
        storage.storage_secret.should == 'new_secret'
        storage.path.should           == 'new_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 10
      end
    end # context 'when setting configuration defaults'

  end # describe '#initialize'

  describe '#provider' do
    it 'should set the Fog provider' do
      storage.send(:provider).should == 'Ninefold'
    end
  end

  describe '#connection' do
    let(:connection) { mock }

    it 'should create a new connection' do
      Fog::Storage.expects(:new).once.with(
        :provider                => 'Ninefold',
        :ninefold_storage_token  => 'my_token',
        :ninefold_storage_secret => 'my_secret'
      ).returns(connection)
      storage.send(:connection).should == connection
    end

    it 'should return an existing connection' do
      Fog::Storage.expects(:new).once.returns(connection)
      storage.send(:connection).should == connection
      storage.send(:connection).should == connection
    end
  end # describe '#connection'

  describe '#directory_for' do
    let(:connection)  { mock }
    let(:directories) { mock }
    let(:directory)   { mock }

    before do
      storage.stubs(:connection).returns(connection)
      connection.stubs(:directories).returns(directories)
    end

    context 'when the directory for the remote_path exists' do
      it 'should return the directory' do
        directories.expects(:get).with('remote_path').returns(directory)
        storage.send(:directory_for, 'remote_path').should be(directory)
      end
    end

    context 'when the directory for the remote_path does not exist' do
      before do
        directories.expects(:get).with('remote_path').returns(nil)
      end

      context 'when create is set to false' do
        it 'should return nil' do
          storage.send(:directory_for, 'remote_path').should be_nil
        end
      end

      context 'when create is set to true' do
        it 'should create and return the directory' do
          directories.expects(:create).with(:key => 'remote_path').returns(directory)
          storage.send(:directory_for, 'remote_path', true).should be(directory)
        end
      end
    end
  end # describe '#directory_for'

  describe '#remote_path_for' do
    let(:package) { mock }

    before do
      # for superclass method
      package.expects(:trigger).returns('trigger')
      package.expects(:time).returns('time')
    end

    it 'should remove any preceeding slash from the remote path' do
      storage.path = '/backups'
      storage.send(:remote_path_for, package).should == 'backups/trigger/time'
    end
  end

  describe '#transfer!' do
    let(:package) { mock }
    let(:directory)       { mock }
    let(:directory_files) { mock }
    let(:file) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      storage.stubs(:storage_name).returns('Storage::Ninefold')
      storage.stubs(:local_path).returns('/local/path')
      directory.stubs(:files).returns(directory_files)
    end

    it 'should transfer the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      storage.expects(:directory_for).with('remote/path', true).returns(directory)

      storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Ninefold started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa'."
      )
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'), 'r'
      ).yields(file)
      directory_files.expects(:create).in_sequence(s).with(
        :key => 'backup.tar.enc-aa', :body => file
      )
      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Ninefold started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab'."
      )
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab'), 'r'
      ).yields(file)
      directory_files.expects(:create).in_sequence(s).with(
        :key => 'backup.tar.enc-ab', :body => file
      )

      storage.send(:transfer!)
    end
  end # describe '#transfer!'

  describe '#remove!' do
    let(:package) { mock }
    let(:directory)       { mock }
    let(:directory_files) { mock }
    let(:file) { mock }
    let(:s) { sequence '' }

    before do
      storage.stubs(:storage_name).returns('Storage::Ninefold')
      directory.stubs(:files).returns(directory_files)
    end

    it 'should remove the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      storage.expects(:directory_for).with('remote/path').returns(directory)

      storage.expects(:transferred_files_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Ninefold started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' from Ninefold."
      )
      directory_files.expects(:get).in_sequence(s).
          with('backup.tar.enc-aa').returns(file)
      file.expects(:destroy).in_sequence(s)
      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Ninefold started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' from Ninefold."
      )
      directory_files.expects(:get).in_sequence(s).
          with('backup.tar.enc-ab').returns(file)
      file.expects(:destroy).in_sequence(s)

      directory.expects(:destroy).in_sequence(s)

      expect do
        storage.send(:remove!, package)
      end.not_to raise_error
    end

    context 'when the remote directory does not exist' do
      it 'should raise an error' do
        storage.expects(:remote_path_for).in_sequence(s).with(package).
            returns('remote/path')
        storage.expects(:directory_for).with('remote/path').returns(nil)

        storage.expects(:transferred_files_for).never
        directory_files.expects(:get).never
        file.expects(:destroy).never
        directory.expects(:destroy).never

        expect do
          storage.send(:remove!, package)
        end.to raise_error {|err|
          err.should be_an_instance_of Backup::Errors::Storage::Ninefold::NotFoundError
          err.message.should == 'Storage::Ninefold::NotFoundError: ' +
              "Directory at 'remote/path' not found"
        }
      end
    end

    context 'when remote files do not exist' do
      it 'should collect their names and raise an error after proceeding' do
        storage.expects(:remote_path_for).in_sequence(s).with(package).
            returns('remote/path')
        storage.expects(:directory_for).with('remote/path').returns(directory)

        storage.expects(:transferred_files_for).in_sequence(s).with(package).
          multiple_yields(
          ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
          ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab'],
          ['2011.12.31.11.00.02.backup.tar.enc-ac', 'backup.tar.enc-ac']
        )
        # first yield (file not found)
        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::Ninefold started removing " +
          "'2011.12.31.11.00.02.backup.tar.enc-aa' from Ninefold."
        )
        directory_files.expects(:get).in_sequence(s).
            with('backup.tar.enc-aa').returns(nil)
        # second yield (file found and removed)
        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::Ninefold started removing " +
          "'2011.12.31.11.00.02.backup.tar.enc-ab' from Ninefold."
        )
        directory_files.expects(:get).in_sequence(s).
            with('backup.tar.enc-ab').returns(file)
        file.expects(:destroy).in_sequence(s)
        # third yield (file not found)
        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::Ninefold started removing " +
          "'2011.12.31.11.00.02.backup.tar.enc-ac' from Ninefold."
        )
        directory_files.expects(:get).in_sequence(s).
            with('backup.tar.enc-ac').returns(nil)

        # directory removed
        directory.expects(:destroy).in_sequence(s)

        expect do
          storage.send(:remove!, package)
        end.to raise_error {|err|
          err.should be_an_instance_of Backup::Errors::Storage::Ninefold::NotFoundError
          err.message.should == 'Storage::Ninefold::NotFoundError: ' +
              "The following file(s) were not found in 'remote/path'\n" +
              "  backup.tar.enc-aa\n  backup.tar.enc-ac"
        }
      end
    end
  end # describe '#remove!'

end
