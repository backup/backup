# encoding: utf-8

module Backup
shared_examples 'a subclass of Storage::Base' do
  # call should set :cycling_supported true/false
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:storage) { described_class.new(model) }
  let(:storage_name) { described_class.name.sub('Backup::', '') }
  let(:s) { sequence '' }

  describe '#initialize' do

    it 'sets a reference to the model' do
      expect( storage.model ).to be model
    end

    it 'sets a reference to the package' do
      expect( storage.package ).to be model.package
    end

    it 'cleans storage_id for filename use' do
      storage = described_class.new(model, :my_id)
      expect( storage.storage_id ).to eq 'my_id'

      storage = described_class.new(model, 'My #1 ID')
      expect( storage.storage_id ).to eq 'My__1_ID'
    end

  end # describe '#initialize'

  describe '#perform!' do

    context 'when keep is set' do
      before { storage.keep = 1 }

      specify 'storage cycles if supported' do
        Logger.expects(:info).in_sequence(s).with("#{ storage_name } Started...")
        storage.expects(:transfer!).in_sequence(s)
        if cycling_supported
          Logger.expects(:info).in_sequence(s).with("Cycling Started...")
          Storage::Cycler.expects(:cycle!).in_sequence(s).with(storage)
        else
          Storage::Cycler.expects(:cycle!).never
        end
        Logger.expects(:info).in_sequence(s).with("#{ storage_name } Finished!")

        storage.perform!
      end
    end

    context 'when keep is not set' do
      specify 'storage does not cycle' do
        Logger.expects(:info).in_sequence(s).with("#{ storage_name } Started...")
        storage.expects(:transfer!).in_sequence(s)
        Storage::Cycler.expects(:cycle!).never
        Logger.expects(:info).in_sequence(s).with("#{ storage_name } Finished!")

        storage.perform!
      end
    end

    context 'when a storage_id is given' do
      let(:storage) { described_class.new(model, :my_id) }

      specify 'it is used in the log messages' do
        Logger.expects(:info).in_sequence(s).
            with("#{ storage_name } (my_id) Started...")
        storage.expects(:transfer!).in_sequence(s)
        Logger.expects(:info).in_sequence(s).
            with("#{ storage_name } (my_id) Finished!")

        storage.perform!
      end
    end

  end # describe '#perform!'

end
end
