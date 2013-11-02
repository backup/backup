# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::CloudFiles do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:required_config) {
    Proc.new do |cf|
      cf.username   = 'my_username'
      cf.api_key    = 'my_api_key'
      cf.container  = 'my_container'
    end
  }
  let(:storage) { Storage::CloudFiles.new(model, &required_config) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Configuration::Helpers' do
    let(:default_overrides) { { 'segment_size' => 15 } }
    let(:new_overrides) { { 'segment_size' => 20 } }
  end

  it_behaves_like 'a subclass of Storage::Base'

  describe '#initialize' do
    it 'provides default values' do
      # required
      expect( storage.username            ).to eq 'my_username'
      expect( storage.api_key             ).to eq 'my_api_key'
      expect( storage.container           ).to eq 'my_container'

      # defaults
      expect( storage.storage_id          ).to be_nil
      expect( storage.auth_url            ).to be_nil
      expect( storage.region              ).to be_nil
      expect( storage.servicenet          ).to be false
      expect( storage.segments_container  ).to be_nil
      expect( storage.segment_size        ).to be 0
      expect( storage.days_to_keep        ).to be_nil
      expect( storage.max_retries         ).to be 10
      expect( storage.retry_waitsec       ).to be 30
      expect( storage.fog_options         ).to be_nil
      expect( storage.path                ).to eq 'backups'
      expect( storage.keep                ).to be_nil
    end

    it 'configures the storage' do
      storage = Storage::CloudFiles.new(model, :my_id) do |cf|
        cf.username           = 'my_username'
        cf.api_key            = 'my_api_key'
        cf.auth_url           = 'my_auth_url'
        cf.region             = 'my_region'
        cf.servicenet         = true
        cf.container          = 'my_container'
        cf.segments_container = 'my_segments_container'
        cf.segment_size       = 5
        cf.days_to_keep       = 90
        cf.max_retries        = 15
        cf.retry_waitsec      = 45
        cf.fog_options        = { :my_key => 'my_value' }
        cf.path               = 'my/path'
        cf.keep               = 2
      end

      expect( storage.storage_id          ).to eq 'my_id'
      expect( storage.username            ).to eq 'my_username'
      expect( storage.api_key             ).to eq 'my_api_key'
      expect( storage.auth_url            ).to eq 'my_auth_url'
      expect( storage.region              ).to eq 'my_region'
      expect( storage.servicenet          ).to be true
      expect( storage.container           ).to eq 'my_container'
      expect( storage.segments_container  ).to eq 'my_segments_container'
      expect( storage.segment_size        ).to be 5
      expect( storage.days_to_keep        ).to be 90
      expect( storage.max_retries         ).to be 15
      expect( storage.fog_options         ).to eq :my_key => 'my_value'
      expect( storage.retry_waitsec       ).to be 45
      expect( storage.path                ).to eq 'my/path'
      expect( storage.keep                ).to be 2
    end

    it 'strips leading path separator' do
      pre_config = required_config
      storage = Storage::CloudFiles.new(model) do |cf|
        pre_config.call(cf)
        cf.path = '/this/path'
      end
      expect( storage.path ).to eq 'this/path'
    end

    it 'requires username' do
      pre_config = required_config
      expect do
        Storage::CloudFiles.new(model) do |cf|
          pre_config.call(cf)
          cf.username = nil
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/are all required/)
      }
    end

    it 'requires api_key' do
      pre_config = required_config
      expect do
        Storage::CloudFiles.new(model) do |cf|
          pre_config.call(cf)
          cf.api_key = nil
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/are all required/)
      }
    end

    it 'requires container' do
      pre_config = required_config
      expect do
        Storage::CloudFiles.new(model) do |cf|
          pre_config.call(cf)
          cf.container = nil
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/are all required/)
      }
    end

    it 'requires segments_container if segment_size > 0' do
      pre_config = required_config
      expect do
        Storage::CloudFiles.new(model) do |cf|
          pre_config.call(cf)
          cf.segment_size = 1
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/segments_container is required/)
      }
    end

    it 'requires container and segments_container be different' do
      pre_config = required_config
      expect do
        Storage::CloudFiles.new(model) do |cf|
          pre_config.call(cf)
          cf.segments_container = 'my_container'
          cf.segment_size = 1
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/segments_container must not be the same/)
      }
    end

    it 'requires segments_size be <= 5120' do
      pre_config = required_config
      expect do
        Storage::CloudFiles.new(model) do |cf|
          pre_config.call(cf)
          cf.segments_container = 'my_segments_container'
          cf.segment_size = 5121
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/segment_size is too large/)
      }
    end
  end # describe '#initialize'

  describe '#cloud_io' do
    it 'caches a new CloudIO instance' do
      CloudIO::CloudFiles.expects(:new).once.with(
          :username           => 'my_username',
          :api_key            => 'my_api_key',
          :auth_url           => nil,
          :region             => nil,
          :servicenet         => false,
          :container          => 'my_container',
          :segments_container => nil,
          :segment_size       => 0,
          :days_to_keep       => nil,
          :max_retries        => 10,
          :retry_waitsec      => 30,
          :fog_options        => nil
      ).returns(:cloud_io)

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
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'transfers the package files' do
      src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
      dest = File.join(remote_path, 'test_trigger.tar-aa')

      Logger.expects(:info).in_sequence(s).
          with("Storing 'my_container/#{ dest }'...")
      cloud_io.expects(:upload).in_sequence(s).with(src, dest)

      src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
      dest = File.join(remote_path, 'test_trigger.tar-ab')

      Logger.expects(:info).in_sequence(s).
          with("Storing 'my_container/#{ dest }'...")
      cloud_io.expects(:upload).in_sequence(s).with(src, dest)

      storage.send(:transfer!)

      expect( storage.package.no_cycle ).to be_false
    end

    context 'when days_to_keep is set' do
      before { storage.days_to_keep = 1 }

      it 'marks package so the cycler will not attempt to remove it' do
        cloud_io.stubs(:upload)
        storage.send(:transfer!)
        expect( storage.package.no_cycle ).to be_true
      end
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
    let(:package_file_a) {
      stub(:marked_for_deletion? => false, :slo? => true)
    }
    let(:package_file_b) {
      stub(:marked_for_deletion? => false, :slo? => false)
    }

    before do
      Timecop.freeze
      storage.stubs(:cloud_io).returns(cloud_io)
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'removes the given package from the remote' do
      Logger.expects(:info).with("Removing backup package dated #{ timestamp }...")

      objects = [package_file_a, package_file_b]
      cloud_io.expects(:objects).with(remote_path).returns(objects)

      cloud_io.expects(:delete_slo).with([package_file_a])
      cloud_io.expects(:delete).with([package_file_b])

      storage.send(:remove!, package)
    end

    it 'raises an error if remote package is missing' do
      objects = []
      cloud_io.expects(:objects).with(remote_path).returns(objects)
      cloud_io.expects(:delete_slo).never
      cloud_io.expects(:delete).never

      expect do
        storage.send(:remove!, package)
      end.to raise_error(
        Storage::CloudFiles::Error,
        "Storage::CloudFiles::Error: Package at '#{ remote_path }' not found"
      )
    end

  end # describe '#remove!'
end
end
