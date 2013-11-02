# encoding: utf-8
require File.expand_path('../../../spec_helper.rb', __FILE__)

module Backup
describe Syncer::Cloud::S3 do
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
  let(:syncer) { Syncer::Cloud::S3.new(&required_config) }

  it_behaves_like 'a class that includes Configuration::Helpers' do
    let(:default_overrides) {
      { 'encryption' => :aes256,
        'storage_class' => :reduced_redundancy }
    }
    let(:new_overrides) {
      { 'encryption' => 'aes256',
        'storage_class' => 'standard' }
    }
  end

  it_behaves_like 'a subclass of Syncer::Cloud::Base'

  describe '#initialize' do
    it 'provides default values' do
      # required
      expect( syncer.bucket             ).to eq 'my_bucket'
      # required unless using IAM profile
      expect( syncer.access_key_id      ).to eq 'my_access_key_id'
      expect( syncer.secret_access_key  ).to eq 'my_secret_access_key'

      # defaults
      expect( syncer.use_iam_profile  ).to be_nil
      expect( syncer.region           ).to be_nil
      expect( syncer.encryption       ).to be_nil
      expect( syncer.storage_class    ).to eq :standard
      expect( syncer.fog_options      ).to be_nil

      # from Syncer::Cloud::Base
      expect( syncer.thread_count   ).to be 0
      expect( syncer.max_retries    ).to be 10
      expect( syncer.retry_waitsec  ).to be 30
      expect( syncer.path           ).to eq 'backups'

      # from Syncer::Base
      expect( syncer.syncer_id      ).to be_nil
      expect( syncer.mirror         ).to be(false)
      expect( syncer.directories    ).to eq []
    end

    it 'configures the syncer' do
      syncer = Syncer::Cloud::S3.new(:my_id) do |s3|
        s3.access_key_id      = 'my_access_key_id'
        s3.secret_access_key  = 'my_secret_access_key'
        s3.bucket             = 'my_bucket'
        s3.region             = 'my_region'
        s3.encryption         = :aes256
        s3.storage_class      = :reduced_redundancy
        s3.thread_count       = 5
        s3.max_retries        = 15
        s3.retry_waitsec      = 45
        s3.path               = 'my_backups'
        s3.mirror             = true
        s3.fog_options        = { :my_key => 'my_value' }

        s3.directories do
          add '/this/path'
          add 'that/path'
        end
      end

      expect( syncer.access_key_id      ).to eq 'my_access_key_id'
      expect( syncer.secret_access_key  ).to eq 'my_secret_access_key'
      expect( syncer.use_iam_profile    ).to be_nil
      expect( syncer.bucket             ).to eq 'my_bucket'
      expect( syncer.region             ).to eq 'my_region'
      expect( syncer.encryption         ).to eq :aes256
      expect( syncer.storage_class      ).to eq :reduced_redundancy
      expect( syncer.thread_count       ).to be 5
      expect( syncer.max_retries        ).to be 15
      expect( syncer.retry_waitsec      ).to be 45
      expect( syncer.path               ).to eq 'my_backups'
      expect( syncer.syncer_id          ).to eq :my_id
      expect( syncer.mirror             ).to be(true)
      expect( syncer.fog_options        ).to eq :my_key => 'my_value'
      expect( syncer.directories        ).to eq ['/this/path', 'that/path']
    end

    it 'requires bucket' do
      pre_config = required_config
      expect do
        Syncer::Cloud::S3.new do |s3|
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
          Syncer::Cloud::S3.new do |s3|
            pre_config.call(s3)
          end
        end.not_to raise_error
      end
    end

    context 'when using AWS access keys' do
      it 'requires access_key_id' do
        pre_config = required_config
        expect do
          Syncer::Cloud::S3.new do |s3|
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
          Syncer::Cloud::S3.new do |s3|
            pre_config.call(s3)
            s3.secret_access_key = nil
          end
        end.to raise_error {|err|
          expect( err.message ).to match(/are all required/)
        }
      end
    end

    it 'validates encryption' do
      pre_config = required_config
      expect do
        Syncer::Cloud::S3.new do |s3|
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
        Syncer::Cloud::S3.new do |s3|
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
          :bucket             => 'my_bucket',
          :region             => nil,
          :encryption         => nil,
          :storage_class      => :standard,
          :max_retries        => 10,
          :retry_waitsec      => 30,
          :chunk_size         => 0,
          :fog_options        => nil
      ).returns(:cloud_io)

      syncer = Syncer::Cloud::S3.new(&required_config)

      expect( syncer.send(:cloud_io) ).to eq :cloud_io
      expect( syncer.send(:cloud_io) ).to eq :cloud_io
    end

    specify 'when using AWS IAM profile' do
      CloudIO::S3.expects(:new).once.with(
          :access_key_id      => nil,
          :secret_access_key  => nil,
          :use_iam_profile    => true,
          :bucket             => 'my_bucket',
          :region             => nil,
          :encryption         => nil,
          :storage_class      => :standard,
          :max_retries        => 10,
          :retry_waitsec      => 30,
          :chunk_size         => 0,
          :fog_options        => nil
      ).returns(:cloud_io)

      syncer = Syncer::Cloud::S3.new(&required_iam_config)

      expect( syncer.send(:cloud_io) ).to eq :cloud_io
      expect( syncer.send(:cloud_io) ).to eq :cloud_io
    end
  end # describe '#cloud_io'

  describe '#get_remote_files' do
    let(:cloud_io) { mock }
    let(:object_a) {
      stub(
        :key => 'my/path/dir_to_sync/some_dir/object_a',
        :etag => '12345'
      )
    }
    let(:object_b) {
      stub(
        :key => 'my/path/dir_to_sync/another_dir/object_b',
        :etag => '67890'
      )
    }
    before { syncer.stubs(:cloud_io).returns(cloud_io) }

    it 'returns a hash of relative paths and checksums for remote objects' do
      cloud_io.expects(:objects).with('my/path/dir_to_sync').
          returns([object_a, object_b])

      expect(
        syncer.send(:get_remote_files, 'my/path/dir_to_sync')
      ).to eq(
        { 'some_dir/object_a' => '12345', 'another_dir/object_b' => '67890' }
      )
    end

    it 'returns an empty hash if no remote objects are found' do
      cloud_io.expects(:objects).returns([])
      expect( syncer.send(:get_remote_files, 'foo') ).to eq({})
    end
  end # describe '#get_remote_files'

  describe 'Deprecations' do
    include_examples 'Deprecation: #concurrency_type and #concurrency_level'
  end

end
end
