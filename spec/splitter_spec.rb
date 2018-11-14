require "spec_helper"

module Backup
  describe Splitter do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:package) { model.package }
    let(:splitter) { Splitter.new(model, 250, 2) }
    let(:splitter_long_suffix) { Splitter.new(model, 250, 3) }
    let(:s) { sequence "" }

    before do
      allow_any_instance_of(Splitter).to receive(:utility).with(:split).and_return("split")
    end

    # Note: BSD split will not accept a 'M' suffix for the byte size
    # e.g. split -a 2 -b 250M

    describe "#initialize" do
      it "sets instance variables" do
        expect(splitter.package).to be package
        expect(splitter.chunk_size).to be 250
        expect(splitter.suffix_length).to be 2

        expect(splitter_long_suffix.package).to be package
        expect(splitter_long_suffix.chunk_size).to be 250
        expect(splitter_long_suffix.suffix_length).to be 3
      end
    end

    describe "#split_with" do
      let(:given_block) { double }
      let(:block) { ->(arg) { given_block.got(arg) } }

      shared_examples "split suffix handling" do
        context "when final package was larger than chunk_size" do
          it "updates chunk_suffixes for the package" do
            suffixes = ["a" * splitter.suffix_length] * 2
            suffixes.last.next!
            allow(splitter).to receive(:chunks).and_return(
              suffixes.map { |s| "/tmp/test_trigger.tar-#{s}" }
            )

            expect(given_block).to receive(:got).ordered.with(
              "split -a #{splitter.suffix_length} -b 250m - " \
              "'#{File.join(Config.tmp_path, "test_trigger.tar-")}'"
            )

            expect(FileUtils).to receive(:mv).never

            splitter.split_with(&block)

            expect(package.chunk_suffixes).to eq suffixes
          end
        end

        context "when final package was not larger than chunk_size" do
          it "removes the suffix from the single file output by split" do
            suffix = "a" * splitter.suffix_length
            allow(splitter).to receive(:chunks).and_return(["/tmp/test_trigger.tar-#{suffix}"])

            expect(given_block).to receive(:got).ordered.with(
              "split -a #{splitter.suffix_length} -b 250m - " \
              "'#{File.join(Config.tmp_path, "test_trigger.tar-")}'"
            )

            expect(FileUtils).to receive(:mv).ordered.with(
              File.join(Config.tmp_path, "test_trigger.tar-#{suffix}"),
              File.join(Config.tmp_path, "test_trigger.tar")
            )

            splitter.split_with(&block)

            expect(package.chunk_suffixes).to eq []
          end
        end
      end

      context "with suffix_length of 2" do
        let(:splitter) { Splitter.new(model, 250, 2) }
        include_examples "split suffix handling"
      end

      context "with suffix_length of 3" do
        let(:splitter) { Splitter.new(model, 250, 3) }
        include_examples "split suffix handling"
      end
    end # describe '#split_with'

    describe "#chunks" do
      before do
        @tmpdir = Dir.mktmpdir("backup_spec")
        SandboxFileUtils.activate!(@tmpdir)
        Config.send(:update, root_path: @tmpdir)
        FileUtils.mkdir_p(Config.tmp_path)
      end

      after do
        FileUtils.rm_r(@tmpdir, force: true, secure: true)
      end

      it "should return a sorted array of chunked file paths" do
        files = [
          "test_trigger.tar-aa",
          "test_trigger.tar-ab",
          "other_trigger.tar-aa"
        ].map { |name| File.join(Config.tmp_path, name) }
        FileUtils.touch(files)

        expect(splitter.send(:chunks)).to eq files[0..1]
      end
    end
  end
end
