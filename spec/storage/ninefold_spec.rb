# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::Ninefold do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::Ninefold.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Storage::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( storage.storage_id      ).to be_nil
      expect( storage.keep            ).to be_nil
      expect( storage.storage_token   ).to be_nil
      expect( storage.storage_secret  ).to be_nil
      expect( storage.path            ).to eq 'backups'
    end

    it 'configures the storage' do
      storage = Storage::Ninefold.new(model, :my_id) do |nf|
        nf.keep           = 2
        nf.storage_token  = 'my_storage_token'
        nf.storage_secret = 'my_storage_secret'
        nf.path           = 'my/path'
      end

      expect( storage.storage_id      ).to eq 'my_id'
      expect( storage.keep            ).to be 2
      expect( storage.storage_token   ).to eq 'my_storage_token'
      expect( storage.storage_secret  ).to eq 'my_storage_secret'
      expect( storage.path            ).to eq 'my/path'
    end

    it 'strips leading path separator' do
      storage = Storage::Ninefold.new(model) do |s3|
        s3.path = '/this/path'
      end
      expect( storage.path ).to eq 'this/path'
    end

  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    before do
      storage.storage_token  = 'my_storage_token'
      storage.storage_secret = 'my_storage_secret'
    end

    it 'creates a new connection' do
      Fog::Storage.expects(:new).with(
        :provider                 => 'Ninefold',
        :ninefold_storage_token   => 'my_storage_token',
        :ninefold_storage_secret  => 'my_storage_secret'
      ).returns(connection)
      expect( storage.send(:connection) ).to eq connection
    end

    it 'caches the connection' do
      Fog::Storage.expects(:new).once.returns(connection)
      expect( storage.send(:connection) ).to eq connection
      expect( storage.send(:connection) ).to eq connection
    end

  end # describe '#connection'

  describe '#transfer!' do
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
    let(:directory) { mock }
    let(:files) { mock }
    let(:file) { mock }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.package.stubs(:filenames).returns(
        ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
      directory.stubs(:files).returns(files)
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'transfers the package files' do
      storage.expects(:directory_for).with(remote_path, true).returns(directory)

      src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
      dest = File.join(remote_path, 'test_trigger.tar-aa')

      Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
      File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
      files.expects(:create).in_sequence(s).with(
        { :key => 'test_trigger.tar-aa', :body => file }
      )

      src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
      dest = File.join(remote_path, 'test_trigger.tar-ab')

      Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
      File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
      files.expects(:create).in_sequence(s).with(
        { :key => 'test_trigger.tar-ab', :body => file }
      )

      storage.send(:transfer!)
    end

  end # describe '#transfer!'

  describe '#directory_for' do
    let(:connection)  { mock }
    let(:directories) { mock }
    let(:directory)   { mock }

    before do
      storage.stubs(:connection).returns(connection)
      connection.stubs(:directories).returns(directories)
    end

    context 'when the directory for the remote_path exists' do
      it 'returns the directory' do
        directories.expects(:get).with('remote/path').returns(directory)
        storage.send(:directory_for, 'remote/path').should be(directory)
      end
    end

    context 'when the directory for the remote_path does not exist' do
      before do
        directories.expects(:get).with('remote/path').returns(nil)
      end

      context 'when create is set to false' do
        it 'returns nil' do
          storage.send(:directory_for, 'remote/path').should be_nil
        end
      end

      context 'when create is set to true' do
        it 'creates and returns the directory' do
          directories.expects(:create).with(:key => 'remote/path').returns(directory)
          storage.send(:directory_for, 'remote/path', true).should be(directory)
        end
      end
    end
  end # describe '#directory_for'

  describe '#remove!' do
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
    let(:directory) { mock }
    let(:files) { mock }
    let(:file) { mock }
    let(:package) {
      stub( # loaded from YAML storage file
        :trigger    => 'test_trigger',
        :time       => timestamp,
        :filenames  => ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
    }

    before do
      Timecop.freeze
      directory.stubs(:files).returns(files)
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'removes the given package from the remote' do
      Logger.expects(:info).in_sequence(s).
          with("Removing backup package dated #{ timestamp }...")

      storage.expects(:directory_for).with(remote_path).returns(directory)

      target = File.join(remote_path, 'test_trigger.tar-aa')
      files.expects(:get).in_sequence(s).with('test_trigger.tar-aa').returns(file)
      file.expects(:destroy).in_sequence(s)

      target = File.join(remote_path, 'test_trigger.tar-ab')
      files.expects(:get).in_sequence(s).with('test_trigger.tar-ab').returns(file)
      file.expects(:destroy).in_sequence(s)

      directory.expects(:destroy).in_sequence(s)

      storage.send(:remove!, package)
    end

    it 'ignores missing files on the remote' do
      Logger.expects(:info).in_sequence(s).
          with("Removing backup package dated #{ timestamp }...")

      storage.expects(:directory_for).with(remote_path).returns(directory)

      target = File.join(remote_path, 'test_trigger.tar-aa')
      files.expects(:get).in_sequence(s).with('test_trigger.tar-aa').returns(nil)

      target = File.join(remote_path, 'test_trigger.tar-ab')
      files.expects(:get).in_sequence(s).with('test_trigger.tar-ab').returns(file)
      file.expects(:destroy).in_sequence(s)

      directory.expects(:destroy).in_sequence(s)

      storage.send(:remove!, package)
    end

    it 'raises an error if the remote_path is missing' do
      Logger.expects(:info).in_sequence(s).
          with("Removing backup package dated #{ timestamp }...")

      storage.expects(:directory_for).with(remote_path).returns(nil)

      files.expects(:get).never
      directory.expects(:destroy).never

      expect do
        storage.send(:remove!, package)
      end.to raise_error(Storage::Ninefold::Error) {|err|
        expect( err.message ).to eq(
          'Storage::Ninefold::Error: ' +
          "Directory at '#{ remote_path }' not found"
        )
      }
    end
  end # describe '#remove!'

end
end
