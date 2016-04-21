# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::GoogleDrive do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:required_config) {
    Proc.new do |gd|
      gd.refresh_token = 'my_token'
      gd.gdrive_exe    = '/path/to/gdrive'
    end
  }
  let(:storage) { Storage::GoogleDrive.new(model, &required_config) }
  let(:s) { sequence '' }

  it_behaves_like 'a subclass of Storage::Base'
  it_behaves_like 'a storage that cycles'

  describe '#initialize' do
    it 'provides default values' do
      # required
      expect( storage.refresh_token       ).to eq 'my_token'
      expect( storage.gdrive_exe          ).to eq '/path/to/gdrive'
      # defaults
      expect( storage.path                ).to eq 'backups'
      expect( storage.keep                ).to be_nil
    end

    it 'configures the storage' do
      storage = Storage::GoogleDrive.new(model, :my_id) do |gd|
        gd.refresh_token      = 'my_token'
        gd.gdrive_exe         = '/path/to/gdrive'
        gd.path               = 'my/path'
        gd.keep               = 2
      end

      expect( storage.refresh_token       ).to eq 'my_token'
      expect( storage.gdrive_exe          ).to eq '/path/to/gdrive'

      expect( storage.path                ).to eq 'my/path'
      expect( storage.keep                ).to be 2
    end

    it 'strips leading path separator' do
      pre_config = required_config
      storage = Storage::GoogleDrive.new(model) do |gd|
        pre_config.call(gd)
        gd.path = '/this/path'
      end
      expect( storage.path ).to eq 'this/path'
    end

    it 'requires refresh_token' do
      pre_config = required_config
      expect do
        Storage::GoogleDrive.new(model) do |gd|
          pre_config.call(gd)
          gd.refresh_token = nil
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/is required/)
      }
    end

    it 'requires gdrive executable in PATH' do
      pre_config = required_config
      expect do
        Storage::GoogleDrive.new(model) do |gd|
          pre_config.call(gd)
          gd.gdrive_exe = nil
        end
      end.to raise_error {|err|
        expect( err.message ).to match(/gdrive executable is required/)
      }
    end
  end # describe '#initialize'

  # Not really sure how to test actual transfers?
end
end
