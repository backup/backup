# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::Ninefold do

  let(:ninefold) do
    Backup::Storage::Ninefold.new do |nf|
      nf.storage_token  = 'my_storage_token'
      nf.storage_secret = 'my_storage_secret'
      nf.path           = 'backups'
      nf.keep           = 20
    end
  end

  before do
    Backup::Configuration::Storage::Ninefold.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    ninefold.storage_token.should  == 'my_storage_token'
    ninefold.storage_secret.should == 'my_storage_secret'
    ninefold.keep.should           == 20
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::Ninefold.defaults do |nf|
      nf.storage_token = 'my_storage_token'
      nf.keep          = 500
    end

    ninefold = Backup::Storage::Ninefold.new do |nf|
      nf.path = 'my/backups'
    end

    ninefold.storage_token.should  == 'my_storage_token' # not defined, uses default
    ninefold.storage_secret.should == nil                # not defined, no default
    ninefold.path.should           == 'my/backups'       # overwritten from Backup::Storage::Ninefold
    ninefold.keep.should           == 500                # comes from the default configuration
  end

  describe '#provider' do
    it 'should be Ninefold' do
      ninefold.provider.should == 'Ninefold'
    end
  end

  describe '#perform' do
    it 'should invoke transfer! and cycle!' do
      ninefold.expects(:transfer!)
      ninefold.expects(:cycle!)
      ninefold.perform!
    end
  end

  describe '#connection' do
    it 'should establish and re-use a connection to Ninefold' do
      Fog::Storage.expects(:new).once.with({
        :provider                => 'Ninefold',
        :ninefold_storage_token  => 'my_storage_token',
        :ninefold_storage_secret => 'my_storage_secret'
      }).returns(true)

      ninefold.send(:connection)
      ninefold.send(:connection)
    end
  end

  describe '#transfer!' do
    let(:connection)  { mock('Fog::Storage') }
    let(:directories) { mock('Fog::Storage::Ninefold::Directories') }
    let(:directory)   { mock('Fog::Storage::Ninefold::Directory') }
    let(:files)       { mock('Fog::Storage::Ninefold::Files') }

    before do
      Fog::Storage.expects(:new).once.returns(connection)
      connection.stubs(:directories).returns(directories)
      directory.stubs(:files).returns(files)
    end

    context 'directory already exists' do
      it 'should transfer the provided file to the directory' do
        Backup::Model.new('blah', 'blah') {}
        file = mock("Backup::Storage::Ninefold::File")
        File.expects(:open).with("#{File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER}")}.tar").returns(file)

        directories.expects(:get).with("backups/myapp/#{ Backup::TIME }").returns(directory)
        files.expects(:create) do |options|
          options[:key].should == "#{ Backup::TRIGGER }.tar"
          options[:body].should == file
        end

        ninefold.send(:transfer!)
      end
    end

    context 'directory does not yet exist' do
      it 'should transfer the provided file to the directory' do
        Backup::Model.new('blah', 'blah') {}
        file = mock("Backup::Storage::Ninefold::File")
        File.expects(:open).with("#{File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER}")}.tar").returns(file)

        directories.expects(:get).with("backups/myapp/#{ Backup::TIME }").returns(nil)
        directories.expects(:create) { |options|
          options[:key].should == "backups/myapp/#{ Backup::TIME }"
        }.returns(directory)

        files.expects(:create) do |options|
          options[:key].should == "#{ Backup::TRIGGER }.tar"
          options[:body].should == file
        end

        ninefold.send(:transfer!)
      end
    end
  end

  describe '#remove!' do
    let(:connection)  { mock('Fog::Storage') }
    let(:directories) { mock('Fog::Storage::Ninefold::Directories') }
    let(:directory)   { mock('Fog::Storage::Ninefold::Directory') }
    let(:files)       { mock('Fog::Storage::Ninefold::Files') }
    let(:file)        { mock('Fog::Storage::Ninefold::File') }

    before do
      Fog::Storage.expects(:new).once.returns(connection)
      connection.stubs(:directories).returns(directories)
      directory.stubs(:files).returns(files)
    end

    it 'should remove the file from the bucket' do
      directories.expects(:get).
          with("backups/myapp/#{ Backup::TIME }").
          returns(directory)
      files.expects(:get).
          with("#{ Backup::TRIGGER }.tar").
          returns(file)
      file.expects(:destroy)
      directory.expects(:destroy)

      ninefold.send(:remove!)
    end

    it 'should raise an error if remote_path does not exist' do
      directories.expects(:get).
          with("backups/myapp/#{ Backup::TIME }").
          returns(nil)
      files.expects(:get).never
      file.expects(:destroy).never
      directory.expects(:destroy).never

      expect do
        ninefold.send(:remove!)
      end.to raise_error(
        Backup::Errors::Storage::Ninefold::NotFoundError,
        "Storage::Ninefold::NotFoundError: " +
        "Directory at 'backups/myapp/#{Backup::TIME}' not found"
      )

    end

    it 'should raise an error if remote_file does not exist' do
      directories.expects(:get).
          with("backups/myapp/#{ Backup::TIME }").
          returns(directory)
      files.expects(:get).
          with("#{ Backup::TRIGGER }.tar").
          returns(nil)
      file.expects(:destroy).never
      directory.expects(:destroy).never

      expect do
        ninefold.send(:remove!)
      end.to raise_error(
        Backup::Errors::Storage::Ninefold::NotFoundError,
        "Storage::Ninefold::NotFoundError: " +
        "'#{Backup::TRIGGER}.tar' not found in 'backups/myapp/#{Backup::TIME}'"
      )

    end
  end

end
