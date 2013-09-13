# encoding: utf-8

shared_examples 'a subclass of Storage::Base' do
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
      block = respond_to?(:required_config) ? required_config : Proc.new {}

      storage = described_class.new(model, :my_id, &block)
      expect( storage.storage_id ).to eq 'my_id'

      storage = described_class.new(model, 'My #1 ID', &block)
      expect( storage.storage_id ).to eq 'My__1_ID'
    end

  end # describe '#initialize'

  describe '#perform!' do

    context 'when keep is set' do
      before { storage.keep = 1 }

      specify 'storage cycles if supported' do
        supported = respond_to?(:no_cycler) ? false : true

        Backup::Logger.expects(:info).in_sequence(s).
            with("#{ storage_name } Started...")
        storage.expects(:transfer!).in_sequence(s)

        if supported
          Backup::Logger.expects(:info).in_sequence(s).with("Cycling Started...")
          Backup::Storage::Cycler.expects(:cycle!).in_sequence(s).with(storage)
        else
          Backup::Storage::Cycler.expects(:cycle!).never
        end
        Backup::Logger.expects(:info).in_sequence(s).
            with("#{ storage_name } Finished!")

        storage.perform!
      end
    end

    context 'when keep is not set' do
      specify 'storage does not cycle' do
        Backup::Logger.expects(:info).in_sequence(s).
            with("#{ storage_name } Started...")
        storage.expects(:transfer!).in_sequence(s)
        Backup::Storage::Cycler.expects(:cycle!).never
        Backup::Logger.expects(:info).in_sequence(s).
            with("#{ storage_name } Finished!")

        storage.perform!
      end
    end

    context 'when a storage_id is given' do
      specify 'it is used in the log messages' do
        block = respond_to?(:required_config) ? required_config : Proc.new {}
        storage = described_class.new(model, :my_id, &block)

        Backup::Logger.expects(:info).in_sequence(s).
            with("#{ storage_name } (my_id) Started...")
        storage.expects(:transfer!).in_sequence(s)
        Backup::Logger.expects(:info).in_sequence(s).
            with("#{ storage_name } (my_id) Finished!")

        storage.perform!
      end
    end

  end # describe '#perform!'

end
