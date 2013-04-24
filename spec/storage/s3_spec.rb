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
    end

    it 'configures the storage' do
      storage = Storage::S3.new(model, :my_id) do |s3|
        s3.keep               = 2
        s3.access_key_id      = 'my_access_key_id'
        s3.secret_access_key  = 'my_secret_access_key'
        s3.bucket             = 'my_bucket'
        s3.region             = 'my_region'
        s3.path               = 'my/path'
      end

      expect( storage.storage_id        ).to eq 'my_id'
      expect( storage.keep              ).to be 2
      expect( storage.access_key_id     ).to eq 'my_access_key_id'
      expect( storage.secret_access_key ).to eq 'my_secret_access_key'
      expect( storage.bucket            ).to eq 'my_bucket'
      expect( storage.region            ).to eq 'my_region'
      expect( storage.path              ).to eq 'my/path'
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
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
    let(:file) { mock }

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
      File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
      connection.expects(:put_object).in_sequence(s).with('my_bucket', dest, file)

      src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
      dest = File.join(remote_path, 'test_trigger.tar-ab')

      Logger.expects(:info).in_sequence(s).with("Storing 'my_bucket/#{ dest }'...")
      File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
      connection.expects(:put_object).in_sequence(s).with('my_bucket', dest, file)

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
        :time       => timestamp,
        :filenames  => ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
    }

    before do
      Timecop.freeze
      storage.stubs(:connection).returns(connection)
      storage.bucket = 'my_bucket'
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'removes the given package from the remote' do
      Logger.expects(:info).in_sequence(s).
          with("Removing backup package dated #{ timestamp }...")

      target = File.join(remote_path, 'test_trigger.tar-aa')
      connection.expects(:delete_object).in_sequence(s).with('my_bucket', target)

      target = File.join(remote_path, 'test_trigger.tar-ab')
      connection.expects(:delete_object).in_sequence(s).with('my_bucket', target)

      storage.send(:remove!, package)
    end

  end # describe '#remove!'

end
end
