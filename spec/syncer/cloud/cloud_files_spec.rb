# encoding: utf-8
require File.expand_path('../../../spec_helper.rb', __FILE__)

module Backup
describe Syncer::Cloud::CloudFiles do
  let(:required_config) {
    Proc.new do |cf|
      cf.username   = 'my_username'
      cf.api_key    = 'my_api_key'
      cf.container  = 'my_container'
    end
  }
  let(:syncer) { Syncer::Cloud::CloudFiles.new(&required_config) }

  it_behaves_like 'a class that includes Configuration::Helpers'

  it_behaves_like 'a subclass of Syncer::Cloud::Base'

  describe '#initialize' do
    it 'provides default values' do
      # required
      expect( syncer.username       ).to eq 'my_username'
      expect( syncer.api_key        ).to eq 'my_api_key'
      expect( syncer.container      ).to eq 'my_container'

      # defaults
      expect( syncer.auth_url       ).to be_nil
      expect( syncer.region         ).to be_nil
      expect( syncer.servicenet     ).to be(false)
      expect( syncer.fog_options    ).to be_nil

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
      syncer = Syncer::Cloud::CloudFiles.new(:my_id) do |cf|
        cf.username       = 'my_username'
        cf.api_key        = 'my_api_key'
        cf.container      = 'my_container'
        cf.auth_url       = 'my_auth_url'
        cf.region         = 'my_region'
        cf.servicenet     = true
        cf.thread_count   = 5
        cf.max_retries    = 15
        cf.retry_waitsec  = 45
        cf.fog_options    = { :my_key => 'my_value' }
        cf.path           = 'my_backups'
        cf.mirror         = true

        cf.directories do
          add '/this/path'
          add 'that/path'
        end
      end

      expect( syncer.username       ).to eq 'my_username'
      expect( syncer.api_key        ).to eq 'my_api_key'
      expect( syncer.container      ).to eq 'my_container'
      expect( syncer.auth_url       ).to eq 'my_auth_url'
      expect( syncer.region         ).to eq 'my_region'
      expect( syncer.servicenet     ).to be(true)
      expect( syncer.thread_count   ).to be 5
      expect( syncer.max_retries    ).to be 15
      expect( syncer.retry_waitsec  ).to be 45
      expect( syncer.fog_options    ).to eq :my_key => 'my_value'
      expect( syncer.path           ).to eq 'my_backups'
      expect( syncer.syncer_id      ).to eq :my_id
      expect( syncer.mirror         ).to be(true)
      expect( syncer.directories    ).to eq ['/this/path', 'that/path']
    end

    it 'requires username' do
      pre_config = required_config
      expect do
        Syncer::Cloud::CloudFiles.new do |cf|
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
        Syncer::Cloud::CloudFiles.new do |cf|
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
        Syncer::Cloud::CloudFiles.new do |cf|
          pre_config.call(cf)
          cf.container = nil
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/are all required/)
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
          :max_retries        => 10,
          :retry_waitsec      => 30,
          :segments_container => nil,
          :segment_size       => 0,
          :fog_options        => nil
      ).returns(:cloud_io)

      expect( syncer.send(:cloud_io) ).to eq :cloud_io
      expect( syncer.send(:cloud_io) ).to eq :cloud_io
    end
  end # describe '#cloud_io'

  describe '#get_remote_files' do
    let(:cloud_io) { mock }
    let(:object_a) {
      stub(
        :name => 'my/path/dir_to_sync/some_dir/object_a',
        :hash => '12345'
      )
    }
    let(:object_b) {
      stub(
        :name => 'my/path/dir_to_sync/another_dir/object_b',
        :hash => '67890'
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
