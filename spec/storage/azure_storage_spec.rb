# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
  describe Storage::AzureStore do
    let(:model) { Model.new(:test_trigger, 'test label') }
    let(:storage) { Storage::AzureStore.new(model) }

    it_behaves_like 'a class that includes Config::Helpers'
    it_behaves_like 'a subclass of Storage::Base'

    describe '#initialize' do
      it 'provides default values' do
        expect( storage.storage_account    ).to be_nil
        expect( storage.storage_access_key ).to be_nil
        expect( storage.container_name     ).to be_nil
        expect( storage.blob_service       ).to be_nil
        expect( storage.chunk_size         ).to be 1024 * 1024 * 4
        expect( storage.path               ).to eq 'backups'
      end

      it 'configures the storage' do
        storage = Storage::AzureStore.new(model, :my_id) do |db|
          db.storage_account    = 'my_storage_account'
          db.storage_access_key = 'my_storage_access_key'
          db.container_name     = 'my_container'
          db.chunk_size         = 1024
          db.path               = 'my/path'
        end

        expect( storage.storage_account       ).to eq 'my_storage_account'
        expect( storage.storage_access_key    ).to eq 'my_storage_access_key'
        expect( storage.container_name        ).to eq 'my_container'
        expect( storage.chunk_size            ).to eq 1024
        expect( storage.path                  ).to eq 'my/path'
      end
    end # describe '#initialize'
  end
end
