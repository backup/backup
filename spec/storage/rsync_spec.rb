# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::RSync do

  let(:rsync) do
    Backup::Storage::RSync.new do |rsync|
      rsync.username  = 'my_username'
      rsync.password  = 'my_password'
      rsync.ip        = '123.45.678.90'
      rsync.port      = 22
      rsync.path      = '~/backups/'
    end
  end

  before do
    Backup::Configuration::Storage::RSync.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    rsync.username.should == 'my_username'
    rsync.password.should == 'my_password'
    rsync.ip.should       == '123.45.678.90'
    rsync.port.should     == 22
    rsync.path.should     == 'backups/'
    rsync.send(:rsync_port).should == "-e 'ssh -p 22'"
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::RSync.defaults do |rsync|
      rsync.username = 'my_default_username'
      rsync.password = 'my_default_password'
      rsync.path     = '~/backups'
    end

    rsync = Backup::Storage::RSync.new do |rsync|
      rsync.password = 'my_password'
      rsync.ip       = '123.45.678.90'
    end

    rsync.username.should == 'my_default_username'
    rsync.password.should == 'my_password'
    rsync.ip.should       == '123.45.678.90'
    rsync.port.should     == 22
    rsync.send(:rsync_port).should == "-e 'ssh -p 22'"
  end

  it 'should have its own defaults' do
    rsync = Backup::Storage::RSync.new
    rsync.port.should  == 22
    rsync.path.should  == 'backups'
    rsync.local.should == false
    rsync.send(:rsync_port).should == "-e 'ssh -p 22'"
  end

  describe '#perform' do
    it 'should invoke transfer!' do
      s = sequence ''
      rsync.expects(:write_password_file!).in_sequence(s)
      rsync.expects(:transfer!).in_sequence(s)
      rsync.expects(:remove_password_file!).in_sequence(s)

      rsync.perform!
    end

    it 'should ensure any password file is removed' do
      s = sequence ''
      rsync.expects(:write_password_file!).in_sequence(s)
      rsync.expects(:transfer!).in_sequence(s).raises(Exception)
      rsync.expects(:remove_password_file!).in_sequence(s)

      expect do
        rsync.perform!
      end.to raise_error
    end
  end

  describe '#connection' do
    it 'should establish a connection to the remote server' do
      connection = mock
      Net::SSH.expects(:start).with(
        '123.45.678.90',
        'my_username',
        :password => 'my_password',
        :port => 22
      ).yields(connection)

      rsync.send(:connection) do |ssh|
        ssh.should be connection
      end
    end
  end

  describe '#transfer!' do
    let(:local_file)  { File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }
    let(:remote_file) { "#{ Backup::TRIGGER }/#{ Backup::TRIGGER }.tar" }
    let(:pwdfile)     { stub(:path => 'path/to/password/file') }

    before do
      rsync.expects(:create_remote_directories!)
      rsync.expects(:utility).returns('rsync')
      Backup::Logger.expects(:message).with(
        "Storage::RSync started transferring '#{rsync.filename}' to '#{rsync.ip}'."
      )
    end

    context 'when performing a remote transfer' do
      context 'when a password is set' do
        before do
          rsync.stubs(:write_password_file!)
          rsync.instance_variable_set(:@password_file, pwdfile)
        end

        it 'should transfer the provided file to the path' do
          rsync.expects(:run).with(
            "rsync -z -e 'ssh -p 22' --password-file='path/to/password/file' " +
            "'#{local_file}' " +
            "'my_username@123.45.678.90:backups/#{remote_file}'"
          )

          rsync.send(:transfer!)
        end
      end

      context 'when no password is set' do
        before { rsync.password = nil }

        it 'should not provide the --password-file option' do
          rsync.expects(:run).with(
            "rsync -z -e 'ssh -p 22'  " +
            "'#{local_file}' " +
            "'my_username@123.45.678.90:backups/#{remote_file}'"
          )

          rsync.send(:transfer!)
        end
      end

    end # context 'when performing a remote transfer'

    context 'when performing a local transfer' do
      before { rsync.local = true }

      it 'should save a local copy of backups' do
        rsync.expects(:run).with(
          "rsync '#{local_file}' 'backups/#{remote_file}'"
        )
        rsync.send(:transfer!)
      end
    end # context 'when performing a local transfer'
  end

  describe '#remove!' do
    it 'should return nil' do
      rsync.send(:remove!).should == nil
    end
  end

  describe '#create_remote_directories!' do

    context 'when rsync.local is false' do
      it 'should create directories on the remote server' do
        ssh = mock
        rsync.expects(:mkdir).never
        rsync.expects(:connection).yields(ssh)
        ssh.expects(:exec!).with("mkdir -p '#{rsync.remote_path}'")

        rsync.send(:create_remote_directories!)
      end
    end

    context 'when rsync.local is true' do
      before { rsync.local = true }
      it 'should create directories locally' do
        rsync.expects(:mkdir).with(rsync.remote_path)
        rsync.expects(:connection).never

        rsync.send(:create_remote_directories!)
      end
    end

  end

  describe '#write_password_file!' do

    before do
      rsync.instance_variable_defined?(:@password_file).should be_false
    end

    context 'when a password is set' do
      it 'should write the password file' do
        rsync.send(:write_password_file!)
        password_file = rsync.instance_variable_get(:@password_file)
        password_file.should respond_to(:path)
        File.read(password_file.path).should == 'my_password'
      end
    end

    context 'when a password is not set' do
      before { rsync.password = nil }
      it 'should return nil' do
        rsync.send(:write_password_file!).should be_nil
      end
    end

  end # describe '#write_password_file!'

  describe '#remove_password_file!' do
    let(:pwdfile) { mock }

    context 'when @password_file is set' do
      before do
        rsync.instance_variable_set(:@password_file, pwdfile)
      end

      it 'should remove the password file' do
        pwdfile.expects(:delete)
        rsync.send(:remove_password_file!)
      end
    end

    context 'when @password_file is not set' do
      it 'should return nil' do
        rsync.send(:remove_password_file!).should be_nil
      end
    end

  end # describe '#remove_password_file!'

  describe '#rsync_password_file' do
    let(:pwdfile) { stub(:path => 'path/to/password/file') }

    context 'when @password_file is set' do
      before do
        rsync.instance_variable_set(:@password_file, pwdfile)
      end

      it 'should return the password file string for the rsync command' do
        rsync.send(:rsync_password_file).should == "--password-file='path/to/password/file'"
      end
    end

    context 'when a password is not set' do
      it 'should return nil' do
        rsync.send(:rsync_password_file).should be_nil
      end
    end

  end # describe '#password_file'

  describe '#rsync_port' do
    it 'should return the port string for the rsync command' do
      rsync.send(:rsync_port).should == "-e 'ssh -p 22'"
    end
  end

  describe '#rsync_options' do
    it 'should return the options string for the rsync command' do
      rsync.send(:rsync_options).should == "-z"
    end
  end

end
