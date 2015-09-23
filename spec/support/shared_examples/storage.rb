# encoding: utf-8

shared_examples 'a subclass of Storage::Base' do
  let(:storage_name) { described_class.name.sub('Backup::', '') }

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

    # Note that using `storage.expects(:cycle!).never` will cause
    # respond_to?(:cycle!) to return true in Storage#perform! for RSync.
    specify 'does not cycle if keep is not set' do
      Backup::Logger.expects(:info).with("#{ storage_name } Started...")
      storage.expects(:transfer!)
      storage.expects(:cycle!).never
      Backup::Logger.expects(:info).with("#{ storage_name } Finished!")

      storage.perform!
    end

    context 'when a storage_id is given' do
      specify 'it is used in the log messages' do
        block = respond_to?(:required_config) ? required_config : Proc.new {}
        storage = described_class.new(model, :my_id, &block)

        Backup::Logger.expects(:info).with("#{ storage_name } (my_id) Started...")
        storage.expects(:transfer!)
        Backup::Logger.expects(:info).with("#{ storage_name } (my_id) Finished!")

        storage.perform!
      end
    end

  end # describe '#perform!'

end

shared_examples 'a storage that cycles' do
  let(:storage_name) { described_class.name.sub('Backup::', '') }

  shared_examples 'storage cycling' do
    let(:pkg_a) { Backup::Package.new(model) }
    let(:pkg_b) { Backup::Package.new(model) }
    let(:pkg_c) { Backup::Package.new(model) }

    before do
      storage.package.time = Time.now
      pkg_a.time = Time.now - 10
      pkg_b.time = Time.now - 20
      pkg_c.time = Time.now - 30
      stored_packages = [pkg_a, pkg_b, pkg_c]
      (stored_packages + [storage.package]).each do |pkg|
        pkg.time = pkg.time.strftime('%Y.%m.%d.%H.%M.%S')
      end
      File.expects(:exist?).with(yaml_file).returns(true)
      File.expects(:zero?).with(yaml_file).returns(false)
      YAML.expects(:load_file).with(yaml_file).returns(stored_packages)
      storage.stubs(:transfer!)
    end

    it 'cycles packages' do
      storage.expects(:remove!).with(pkg_b)
      storage.expects(:remove!).with(pkg_c)

      FileUtils.expects(:mkdir_p).with(File.dirname(yaml_file))
      file = mock
      File.expects(:open).with(yaml_file, 'w').yields(file)
      saved_packages = [storage.package, pkg_a]
      file.expects(:write).with(saved_packages.to_yaml)

      storage.perform!
    end

    it 'cycles but does not remove packages marked :no_cycle' do
      pkg_b.no_cycle = true
      storage.expects(:remove!).with(pkg_b).never
      storage.expects(:remove!).with(pkg_c)

      FileUtils.expects(:mkdir_p).with(File.dirname(yaml_file))
      file = mock
      File.expects(:open).with(yaml_file, 'w').yields(file)
      saved_packages = [storage.package, pkg_a]
      file.expects(:write).with(saved_packages.to_yaml)

      storage.perform!
    end

    it 'warns if remove fails' do
      storage.expects(:remove!).with(pkg_b).raises('error message')
      storage.expects(:remove!).with(pkg_c)

      pkg_b.stubs(:filenames).returns(['file1', 'file2'])
      Backup::Logger.expects(:warn).with do |err|
        expect( err ).to be_an_instance_of Backup::Storage::Cycler::Error
        expect( err.message ).to include(
          "There was a problem removing the following package:\n" +
          "  Trigger: test_trigger :: Dated: #{ pkg_b.time }\n" +
          "  Package included the following 2 file(s):\n" +
          "  file1\n" +
          "  file2"
        )
        expect( err.message ).to match('RuntimeError: error message')
      end

      FileUtils.expects(:mkdir_p).with(File.dirname(yaml_file))
      file = mock
      File.expects(:open).with(yaml_file, 'w').yields(file)
      saved_packages = [storage.package, pkg_a]
      file.expects(:write).with(saved_packages.to_yaml)

      storage.perform!
    end

  end

  context 'with a storage_id' do
    let(:storage) {
      block = respond_to?(:required_config) ? required_config : Proc.new {}
      described_class.new(model, :my_id, &block)
    }
    let(:yaml_file) { File.join(Backup::Config.data_path, 'test_trigger',
                                "#{ storage_name.split('::').last }-my_id.yml") }

    before { storage.keep = '2' } # value is typecast
    include_examples 'storage cycling'
  end

  context 'without a storage_id' do
    let(:yaml_file) { File.join(Backup::Config.data_path, 'test_trigger',
                                "#{ storage_name.split('::').last }.yml") }
    before { storage.keep = 2 }
    include_examples 'storage cycling'
  end

  context 'keep as a Time' do
    let(:yaml_file) { File.join(Backup::Config.data_path, 'test_trigger',
                                "#{ storage_name.split('::').last }.yml") }
    before { storage.keep = Time.now - 11 }
    include_examples 'storage cycling'
  end

end
