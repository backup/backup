# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::S3 do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:required_config) {
    Proc.new do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.secret_access_key  = 'my_secret_access_key'
      s3.bucket             = 'my_bucket'
    end
  }
  let(:required_iam_config) {
    Proc.new do |s3|
      s3.use_iam_profile  = true
      s3.bucket           = 'my_bucket'
    end
  }
  let(:storage) { Storage::S3.new(model, &required_config) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Configuration::Helpers' do
    let(:default_overrides) {
      { 'chunk_size' => 15,
        'encryption' => :aes256,
        'storage_class' => :reduced_redundancy }
    }
    let(:new_overrides) {
      { 'chunk_size' => 20,
        'encryption' => 'aes256',
        'storage_class' => 'standard' }
    }
  end

  it_behaves_like 'a subclass of Storage::Base'

  describe '#initialize' do
    it 'provides default values' do
      # required
      expect( storage.bucket            ).to eq 'my_bucket'
      # required unless using IAM profile
      expect( storage.access_key_id     ).to eq 'my_access_key_id'
      expect( storage.secret_access_key ).to eq 'my_secret_access_key'

      # defaults
      expect( storage.use_iam_profile   ).to be_nil
      expect( storage.storage_id        ).to be_nil
      expect( storage.keep              ).to be_nil
      expect( storage.region            ).to be_nil
      expect( storage.path              ).to eq 'backups'
      expect( storage.chunk_size        ).to be 5
      expect( storage.max_retries       ).to be 10
      expect( storage.retry_waitsec     ).to be 30
      expect( storage.encryption        ).to be_nil
      expect( storage.storage_class     ).to be :standard
      expect( storage.fog_options       ).to be_nil
    end

    it 'configures the storage' do
      storage = Storage::S3.new(model, :my_id) do |s3|
        s3.keep               = 2
        s3.access_key_id      = 'my_access_key_id'
        s3.secret_access_key  = 'my_secret_access_key'
        s3.bucket             = 'my_bucket'
        s3.region             = 'my_region'
        s3.path               = 'my/path'
        s3.chunk_size         = 10
        s3.max_retries        = 5
        s3.retry_waitsec      = 60
        s3.encryption         = 'aes256'
        s3.storage_class      = :reduced_redundancy
        s3.fog_options        = { :my_key => 'my_value' }
      end

      expect( storage.storage_id        ).to eq 'my_id'
      expect( storage.keep              ).to be 2
      expect( storage.access_key_id     ).to eq 'my_access_key_id'
      expect( storage.secret_access_key ).to eq 'my_secret_access_key'
      expect( storage.use_iam_profile   ).to be_nil
      expect( storage.bucket            ).to eq 'my_bucket'
      expect( storage.region            ).to eq 'my_region'
      expect( storage.path              ).to eq 'my/path'
      expect( storage.chunk_size        ).to be 10
      expect( storage.max_retries       ).to be 5
      expect( storage.retry_waitsec     ).to be 60
      expect( storage.encryption        ).to eq 'aes256'
      expect( storage.storage_class     ).to eq :reduced_redundancy
      expect( storage.fog_options       ).to eq :my_key => 'my_value'
    end

    it 'requires bucket' do
      pre_config = required_config
      expect do
        Storage::S3.new(model) do |s3|
          pre_config.call(s3)
          s3.bucket = nil
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/are all required/)
      }
    end

    context 'when using AWS IAM profile' do
      it 'does not require access_key_id or secret_access_key' do
        pre_config = required_iam_config
        expect do
          Storage::S3.new(model) do |s3|
            pre_config.call(s3)
          end
        end.not_to raise_error
      end
    end

    context 'when using AWS access keys' do
      it 'requires access_key_id' do
        pre_config = required_config
        expect do
          Storage::S3.new(model) do |s3|
            pre_config.call(s3)
            s3.access_key_id = nil
          end
        end.to raise_error {|err|
          expect( err.message ).to match(/are all required/)
        }
      end

      it 'requires secret_access_key' do
        pre_config = required_config
        expect do
          Storage::S3.new(model) do |s3|
            pre_config.call(s3)
            s3.secret_access_key = nil
          end
        end.to raise_error {|err|
          expect( err.message ).to match(/are all required/)
        }
      end
    end

    it 'strips leading path separator' do
      pre_config = required_config
      storage = Storage::S3.new(model) do |s3|
        pre_config.call(s3)
        s3.path = '/this/path'
      end
      expect( storage.path ).to eq 'this/path'
    end

    it 'allows chunk_size 0' do
      pre_config = required_config
      expect do
        Storage::S3.new(model) do |s3|
          pre_config.call(s3)
          s3.chunk_size = 0
        end
      end.not_to raise_error
    end

    it 'validates chunk_size minimum' do
      pre_config = required_config
      expect do
        Storage::S3.new(model) do |s3|
          pre_config.call(s3)
          s3.chunk_size = 4
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/must be between 5 and 5120/)
      }
    end

    it 'validates chunk_size maximum' do
      pre_config = required_config
      expect do
        Storage::S3.new(model) do |s3|
          pre_config.call(s3)
          s3.chunk_size = 5121
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/must be between 5 and 5120/)
      }
    end

    it 'validates encryption' do
      pre_config = required_config
      expect do
        Storage::S3.new(model) do |s3|
          pre_config.call(s3)
          s3.encryption = :aes512
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/must be :aes256 or nil/)
      }
    end

    it 'validates storage_class' do
      pre_config = required_config
      expect do
        Storage::S3.new(model) do |s3|
          pre_config.call(s3)
          s3.storage_class = :glacier
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/must be :standard or :reduced_redundancy/)
      }
    end

  end # describe '#initialize'

  describe '#cloud_io' do
    specify 'when using AWS access keys' do
      CloudIO::S3.expects(:new).once.with(
        :access_key_id      => 'my_access_key_id',
        :secret_access_key  => 'my_secret_access_key',
        :use_iam_profile    => nil,
        :region             => nil,
        :bucket             => 'my_bucket',
        :encryption         => nil,
        :storage_class      => :standard,
        :max_retries        => 10,
        :retry_waitsec      => 30,
        :chunk_size         => 5,
        :fog_options        => nil
      ).returns(:cloud_io)

      storage = Storage::S3.new(model, &required_config)

      expect( storage.send(:cloud_io) ).to eq :cloud_io
      expect( storage.send(:cloud_io) ).to eq :cloud_io
    end

    specify 'when using AWS IAM profile' do
      CloudIO::S3.expects(:new).once.with(
        :access_key_id      => nil,
        :secret_access_key  => nil,
        :use_iam_profile    => true,
        :region             => nil,
        :bucket             => 'my_bucket',
        :encryption         => nil,
        :storage_class      => :standard,
        :max_retries        => 10,
        :retry_waitsec      => 30,
        :chunk_size         => 5,
        :fog_options        => nil
      ).returns(:cloud_io)

      storage = Storage::S3.new(model, &required_iam_config)

      expect( storage.send(:cloud_io) ).to eq :cloud_io
      expect( storage.send(:cloud_io) ).to eq :cloud_io
    end
  end # describe '#cloud_io'

  describe '#transfer!' do
    let(:cloud_io) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.package.stubs(:filenames).returns(
        ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
      storage.stubs(:cloud_io).returns(cloud_io)
      storage.bucket = 'my_bucket'
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'transfers the package files' do
      src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
      dest = File.join(remote_path, 'test_trigger.tar-aa')

      Logger.expects(:info).in_sequence(s).with("Storing 'my_bucket/#{ dest }'...")
      cloud_io.expects(:upload).in_sequence(s).with(src, dest)

      src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
      dest = File.join(remote_path, 'test_trigger.tar-ab')

      Logger.expects(:info).in_sequence(s).with("Storing 'my_bucket/#{ dest }'...")
      cloud_io.expects(:upload).in_sequence(s).with(src, dest)

      storage.send(:transfer!)
    end

  end # describe '#transfer!'

  describe '#remove!' do
    let(:cloud_io) { mock }
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
      storage.stubs(:cloud_io).returns(cloud_io)
      storage.bucket = 'my_bucket'
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'removes the given package from the remote' do
      Logger.expects(:info).with("Removing backup package dated #{ timestamp }...")

      objects = ['some objects']
      cloud_io.expects(:objects).with(remote_path).returns(objects)
      cloud_io.expects(:delete).with(objects)

      storage.send(:remove!, package)
    end

    it 'raises an error if remote package is missing' do
      objects = []
      cloud_io.expects(:objects).with(remote_path).returns(objects)
      cloud_io.expects(:delete).never

      expect do
        storage.send(:remove!, package)
      end.to raise_error(
        Storage::S3::Error,
        "Storage::S3::Error: Package at '#{ remote_path }' not found"
      )
    end

  end # describe '#remove!'

end
end
