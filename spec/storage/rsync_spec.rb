# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::RSync do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::RSync.new(model) do |rsync|
      rsync.username  = 'my_username'
      rsync.password  = 'my_password'
      rsync.ip        = '123.45.678.90'
      rsync.keep      = 5
    end
  end

  it 'should be a subclass of Storage::Base' do
    Backup::Storage::RSync.
      superclass.should == Backup::Storage::Base
  end

  it 'should include Utilities::Helpers' do
    Backup::Storage::RSync.
        include?(Backup::Utilities::Helpers).should be_true
  end

  describe '#initialize' do
    after { Backup::Storage::RSync.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Storage::RSync.any_instance.expects(:load_defaults!)
      storage
    end

    it 'should pass the model reference to Base' do
      storage.instance_variable_get(:@model).should == model
    end

    it 'should pass the storage_id to Base' do
      storage = Backup::Storage::RSync.new(model, 'my_storage_id')
      storage.storage_id.should == 'my_storage_id'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        storage.username.should == 'my_username'
        storage.password.should == 'my_password'
        storage.ip.should       == '123.45.678.90'
        storage.port.should     == 22
        storage.path.should     == 'backups'
        storage.local.should    == false

        storage.storage_id.should be_nil
        storage.keep.should       == 5
      end

      it 'should use default values if none are given' do
        storage = Backup::Storage::RSync.new(model)

        storage.username.should be_nil
        storage.password.should be_nil
        storage.ip.should       be_nil
        storage.port.should     == 22
        storage.path.should     == 'backups'
        storage.local.should    == false

        storage.storage_id.should be_nil
        storage.keep.should       be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Storage::RSync.defaults do |s|
          s.username  = 'some_username'
          s.password  = 'some_password'
          s.ip        = 'some_ip'
          s.port      = 'some_port'
          s.path      = 'some_path'
          s.local     = 'some_local'
          s.keep      = 'some_keep'
        end
      end

      it 'should use pre-configured defaults' do
        storage = Backup::Storage::RSync.new(model)

        storage.username.should == 'some_username'
        storage.password.should == 'some_password'
        storage.ip.should       == 'some_ip'
        storage.port.should     == 'some_port'
        storage.path.should     == 'some_path'
        storage.local.should    == 'some_local'

        storage.storage_id.should be_nil
        storage.keep.should       == 'some_keep'
      end

      it 'should override pre-configured defaults' do
        storage = Backup::Storage::RSync.new(model) do |s|
          s.username  = 'new_username'
          s.password  = 'new_password'
          s.ip        = 'new_ip'
          s.port      = 'new_port'
          s.path      = 'new_path'
          s.local     = 'new_local'
          s.keep      = 'new_keep'
        end

        storage.username.should == 'new_username'
        storage.password.should == 'new_password'
        storage.ip.should       == 'new_ip'
        storage.port.should     == 'new_port'
        storage.path.should     == 'new_path'
        storage.local.should    == 'new_local'

        storage.storage_id.should be_nil
        storage.keep.should       == 'new_keep'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#remote_path_for' do
    let(:package) { mock }
    before do
      storage.instance_variable_set(:@package, package)
      package.expects(:trigger).returns(model.trigger)
    end

    it 'should override superclass so the time folder is not used' do
      storage.send(:remote_path_for, package).should ==
          File.join('backups', 'test_trigger')
    end
  end

  describe '#connection' do
    let(:connection) { mock }
    it 'should yield a Net::SSH connection' do
      Net::SSH.expects(:start).with(
        '123.45.678.90', 'my_username', :password => 'my_password', :port => 22
      ).yields(connection)

      storage.send(:connection) do |ssh|
        ssh.should be(connection)
      end
    end
  end

  describe '#transfer!' do
    let(:package) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      storage.stubs(:storage_name).returns('Storage::RSync')
      storage.stubs(:local_path).returns('/local/path')
      storage.stubs(:rsync_options).returns(:rsync_options)
      storage.stubs(:rsync_port).returns(:rsync_port)
      storage.stubs(:rsync_password_file).returns(:rsync_password_file)
      storage.expects(:utility).with(:rsync).times(0..2).returns('rsync')
    end

    context 'when @local is set to false' do
      it 'should transfer the package files to the remote' do
        storage.expects(:write_password_file!).in_sequence(s)

        storage.expects(:remote_path_for).in_sequence(s).with(package).
            returns('remote/path')

        storage.expects(:create_remote_path!).in_sequence(s).with('remote/path')

        storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
          multiple_yields(
          ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
          ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
        )
        # first yield
        Backup::Logger.expects(:info).in_sequence(s).with(
          "Storage::RSync started transferring " +
          "'2011.12.31.11.00.02.backup.tar.enc-aa' to '123.45.678.90'."
        )
        storage.expects(:run).in_sequence(s).with(
          "rsync rsync_options rsync_port rsync_password_file " +
          "'#{ File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa') }' " +
          "'my_username@123.45.678.90:#{ File.join('remote/path', 'backup.tar.enc-aa') }'"
        )
        # second yield
        Backup::Logger.expects(:info).in_sequence(s).with(
          "Storage::RSync started transferring " +
          "'2011.12.31.11.00.02.backup.tar.enc-ab' to '123.45.678.90'."
        )
        storage.expects(:run).in_sequence(s).with(
          "rsync rsync_options rsync_port rsync_password_file " +
          "'#{ File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab') }' " +
          "'my_username@123.45.678.90:#{ File.join('remote/path', 'backup.tar.enc-ab') }'"
        )

        storage.expects(:remove_password_file!).in_sequence(s)

        storage.send(:transfer!)
      end

      it 'should ensure password file removal' do
        storage.expects(:write_password_file!).raises('error message')
        storage.expects(:remove_password_file!)

        expect do
          storage.send(:transfer!)
        end.to raise_error(RuntimeError, 'error message')
      end
    end # context 'when @local is set to false'

    context 'when @local is set to true' do
      before { storage.local = true }

      it 'should transfer the package files locally' do
        storage.expects(:write_password_file!).never

        storage.expects(:remote_path_for).in_sequence(s).with(package).
            returns('remote/path')

        storage.expects(:create_remote_path!).in_sequence(s).with('remote/path')

        storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
          multiple_yields(
          ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
          ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
        )
        # first yield
        Backup::Logger.expects(:info).in_sequence(s).with(
          "Storage::RSync started transferring " +
          "'2011.12.31.11.00.02.backup.tar.enc-aa' to 'remote/path'."
        )
        storage.expects(:run).in_sequence(s).with(
          "rsync " +
          "'#{ File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa') }' " +
          "'#{ File.join('remote/path', 'backup.tar.enc-aa') }'"
        )
        # second yield
        Backup::Logger.expects(:info).in_sequence(s).with(
          "Storage::RSync started transferring " +
          "'2011.12.31.11.00.02.backup.tar.enc-ab' to 'remote/path'."
        )
        storage.expects(:run).in_sequence(s).with(
          "rsync " +
          "'#{ File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab') }' " +
          "'#{ File.join('remote/path', 'backup.tar.enc-ab') }'"
        )

        storage.expects(:remove_password_file!).never

        storage.send(:transfer!)
      end

    end # context 'when @local is set to true'

  end # describe '#transfer!'

  ##
  # Note: Storage::RSync doesn't cycle
  describe '#remove!' do
    it 'should never even be called' do
      storage.send(:remove!).should be_nil
    end
  end

  describe '#create_remote_path!' do
    let(:connection) { mock }

    context 'when @local is set to false' do
      it 'should create the remote_path on the remote' do
        FileUtils.expects(:mkdir_p).never

        storage.expects(:connection).yields(connection)
        connection.expects(:exec!).with("mkdir -p 'remote/path'")

        storage.send(:create_remote_path!, 'remote/path')
      end
    end

    context 'when @local is set to true' do
      before { storage.local = true }
      it 'should create the remote_path locally' do
        storage.expects(:connection).never

        FileUtils.expects(:mkdir_p).with('remote/path')

        storage.send(:create_remote_path!, 'remote/path')
      end
    end
  end

  describe '#write_password_file!' do
    let(:file) { mock }

    context 'when a @password is set' do
      it 'should write the password to file and set @password_file' do
        Tempfile.expects(:new).with('backup-rsync-password').returns(file)
        file.expects(:write).with('my_password')
        file.expects(:close)

        storage.send(:write_password_file!)
        storage.instance_variable_get(:@password_file).should be(file)
      end
    end

    context 'when a @password is not set' do
      before { storage.password = nil }
      it 'should do nothing' do
        Tempfile.expects(:new).never

        storage.send(:write_password_file!)
        storage.instance_variable_get(:@password_file).should be_nil
      end
    end
  end

  describe '#remove_password_file!' do
    let(:file) { mock }

    context 'when @password_file is set' do
      before { storage.instance_variable_set(:@password_file, file) }
      it 'should delete the file and clear @password_file' do
        file.expects(:delete)
        storage.send(:remove_password_file!)
        storage.instance_variable_get(:@password_file).should be_nil
      end
    end

    context 'when @password_file is not set' do
      it 'should do nothing' do
        file.expects(:delete).never
        storage.send(:remove_password_file!)
      end
    end
  end

  describe '#rsync_password_file' do
    let(:file) { mock }

    context 'when @password_file is set' do
      before { storage.instance_variable_set(:@password_file, file) }
      it 'should return the syntax for rsync to use the password file' do
        file.expects(:path).returns('/path/to/file')
        storage.send(:rsync_password_file).should == "--password-file='/path/to/file'"
      end
    end

    context 'when @password_file is not set' do
      it 'should return nil' do
        storage.send(:rsync_password_file).should be_nil
      end
    end
  end

  describe '#rsync_port' do
    it 'should return the syntax for rsync to set the port' do
      storage.send(:rsync_port).should == "-e 'ssh -p 22'"
    end
  end

  describe '#rsync_options' do
    it 'should return the syntax for rsync to set other options' do
      storage.send(:rsync_options).should == '-z'
    end
  end

end
