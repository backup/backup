shared_examples "a subclass of Storage::Base" do
  let(:storage_name) { described_class.name.sub("Backup::", "") }

  describe "#initialize" do
    it "sets a reference to the model" do
      expect(storage.model).to be model
    end

    it "sets a reference to the package" do
      expect(storage.package).to be model.package
    end

    it "cleans storage_id for filename use" do
      block = respond_to?(:required_config) ? required_config : proc {}

      storage = described_class.new(model, :my_id, &block)
      expect(storage.storage_id).to eq "my_id"

      storage = described_class.new(model, "My #1 ID", &block)
      expect(storage.storage_id).to eq "My__1_ID"
    end
  end # describe '#initialize'

  describe "#perform!" do
    # Note that using expect(`storage).to receive(:cycle!).never` will cause
    # respond_to?(:cycle!) to return true in Storage#perform! for RSync.
    specify "does not cycle if keep is not set" do
      expect(Backup::Logger).to receive(:info).with("#{storage_name} Started...")
      expect(storage).to receive(:transfer!)
      expect(storage).to receive(:cycle!).never
      expect(Backup::Logger).to receive(:info).with("#{storage_name} Finished!")

      storage.perform!
    end

    context "when a storage_id is given" do
      specify "it is used in the log messages" do
        block = respond_to?(:required_config) ? required_config : proc {}
        storage = described_class.new(model, :my_id, &block)

        expect(Backup::Logger).to receive(:info).with("#{storage_name} (my_id) Started...")
        expect(storage).to receive(:transfer!)
        expect(Backup::Logger).to receive(:info).with("#{storage_name} (my_id) Finished!")

        storage.perform!
      end
    end
  end # describe '#perform!'
end

shared_examples "a storage that cycles" do
  let(:storage_name) { described_class.name.sub("Backup::", "") }

  shared_examples "storage cycling" do
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
        pkg.time = pkg.time.strftime("%Y.%m.%d.%H.%M.%S")
      end
      expect(File).to receive(:exist?).with(yaml_file).and_return(true)
      expect(File).to receive(:zero?).with(yaml_file).and_return(false)

      if YAML.respond_to? :safe_load_file
        expect(YAML).to receive(:safe_load_file)
          .with(yaml_file, permitted_classes: [Backup::Package])
      else
        expect(YAML).to receive(:load_file).with(yaml_file)
      end.and_return(stored_packages)

      allow(storage).to receive(:transfer!)
    end

    it "cycles packages" do
      expect(storage).to receive(:remove!).with(pkg_b)
      expect(storage).to receive(:remove!).with(pkg_c)

      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(yaml_file))
      file = double
      expect(File).to receive(:open).with(yaml_file, "w").and_yield(file)
      saved_packages = [storage.package, pkg_a]
      expect(file).to receive(:write).with(saved_packages.to_yaml)

      storage.perform!
    end

    it "cycles but does not remove packages marked :no_cycle" do
      pkg_b.no_cycle = true
      expect(storage).to receive(:remove!).with(pkg_b).never
      expect(storage).to receive(:remove!).with(pkg_c)

      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(yaml_file))
      file = double
      expect(File).to receive(:open).with(yaml_file, "w").and_yield(file)
      saved_packages = [storage.package, pkg_a]
      expect(file).to receive(:write).with(saved_packages.to_yaml)

      storage.perform!
    end

    it "does cycle when the available packages are more than the keep setting" do
      expect(storage).to receive(:remove!).with(pkg_a).never
      expect(storage).to receive(:remove!).with(pkg_b)
      expect(storage).to receive(:remove!).with(pkg_c)

      storage.keep = 2

      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(yaml_file))
      file = double
      expect(File).to receive(:open).with(yaml_file, "w").and_yield(file)
      saved_packages = [storage.package, pkg_a]
      expect(file).to receive(:write).with(saved_packages.to_yaml)

      storage.perform!
    end

    it "does not cycle when the available packages are less than the keep setting" do
      expect(storage).to receive(:remove!).with(pkg_a).never
      expect(storage).to receive(:remove!).with(pkg_b).never
      expect(storage).to receive(:remove!).with(pkg_c).never

      storage.keep = 5

      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(yaml_file))
      file = double
      expect(File).to receive(:open).with(yaml_file, "w").and_yield(file)
      saved_packages = [storage.package, pkg_a, pkg_b, pkg_c]
      expect(file).to receive(:write).with(saved_packages.to_yaml)

      storage.perform!
    end

    it "warns if remove fails" do
      expect(storage).to receive(:remove!).with(pkg_b).and_raise("error message")
      expect(storage).to receive(:remove!).with(pkg_c)

      allow(pkg_b).to receive(:filenames).and_return(["file1", "file2"])
      expect(Backup::Logger).to receive(:warn) do |err|
        expect(err).to be_an_instance_of Backup::Storage::Cycler::Error
        expect(err.message).to include(
          "There was a problem removing the following package:\n" \
          "  Trigger: test_trigger :: Dated: #{pkg_b.time}\n" \
          "  Package included the following 2 file(s):\n" \
          "  file1\n" \
          "  file2"
        )
        expect(err.message).to match("RuntimeError: error message")
      end

      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(yaml_file))
      file = double
      expect(File).to receive(:open).with(yaml_file, "w").and_yield(file)
      saved_packages = [storage.package, pkg_a]
      expect(file).to receive(:write).with(saved_packages.to_yaml)

      storage.perform!
    end
  end

  context "with a storage_id" do
    let(:storage) do
      block = respond_to?(:required_config) ? required_config : proc {}
      described_class.new(model, :my_id, &block)
    end
    let(:yaml_file) do
      File.join(Backup::Config.data_path, "test_trigger",
        "#{storage_name.split("::").last}-my_id.yml")
    end

    before { storage.keep = "2" } # value is typecast
    include_examples "storage cycling"
  end

  context "without a storage_id" do
    let(:yaml_file) do
      File.join(Backup::Config.data_path, "test_trigger",
        "#{storage_name.split("::").last}.yml")
    end
    before { storage.keep = 2 }
    include_examples "storage cycling"
  end

  context "keep as a Time" do
    let(:yaml_file) do
      File.join(Backup::Config.data_path, "test_trigger",
        "#{storage_name.split("::").last}.yml")
    end
    before { storage.keep = Time.now - 11 }
    include_examples "storage cycling"
  end
end
