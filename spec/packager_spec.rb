require "spec_helper"

describe "Backup::Packager" do
  let(:packager) { Backup::Packager }

  it "should include Utilities::Helpers" do
    expect(packager.instance_eval("class << self; self; end")
      .include?(Backup::Utilities::Helpers)).to eq(true)
  end

  describe "#package!" do
    let(:model)     { double }
    let(:package)   { double }
    let(:encryptor) { double }
    let(:splitter)  { double }
    let(:pipeline)  { double }
    let(:procedure) { double }
    let(:s)         { sequence "" }

    context "when pipeline command is successful" do
      it "should setup variables and perform packaging procedures" do
        expect(model).to receive(:package).ordered.and_return(package)
        expect(model).to receive(:encryptor).ordered.and_return(encryptor)
        expect(model).to receive(:splitter).ordered.and_return(splitter)
        expect(Backup::Pipeline).to receive(:new).ordered.and_return(pipeline)

        expect(Backup::Logger).to receive(:info).ordered.with(
          "Packaging the backup files..."
        )
        expect(packager).to receive(:procedure).ordered.and_return(procedure)
        expect(procedure).to receive(:call).ordered

        expect(pipeline).to receive(:success?).ordered.and_return(true)
        expect(Backup::Logger).to receive(:info).ordered.with(
          "Packaging Complete!"
        )

        packager.package!(model)

        expect(packager.instance_variable_get(:@package)).to be(package)
        expect(packager.instance_variable_get(:@encryptor)).to be(encryptor)
        expect(packager.instance_variable_get(:@splitter)).to be(splitter)
        expect(packager.instance_variable_get(:@pipeline)).to be(pipeline)
      end
    end # context 'when pipeline command is successful'

    context "when pipeline command is not successful" do
      it "should raise an error" do
        expect(model).to receive(:package).ordered.and_return(package)
        expect(model).to receive(:encryptor).ordered.and_return(encryptor)
        expect(model).to receive(:splitter).ordered.and_return(splitter)
        expect(Backup::Pipeline).to receive(:new).ordered.and_return(pipeline)

        expect(Backup::Logger).to receive(:info).ordered.with(
          "Packaging the backup files..."
        )
        expect(packager).to receive(:procedure).ordered.and_return(procedure)
        expect(procedure).to receive(:call).ordered

        expect(pipeline).to receive(:success?).ordered.and_return(false)
        expect(pipeline).to receive(:error_messages).ordered.and_return("pipeline_errors")

        expect do
          packager.package!(model)
        end.to raise_error(
          Backup::Packager::Error,
          "Packager::Error: Failed to Create Backup Package\n" \
          "  pipeline_errors"
        )

        expect(packager.instance_variable_get(:@package)).to be(package)
        expect(packager.instance_variable_get(:@encryptor)).to be(encryptor)
        expect(packager.instance_variable_get(:@splitter)).to be(splitter)
        expect(packager.instance_variable_get(:@pipeline)).to be(pipeline)
      end
    end # context 'when pipeline command is successful'
  end # describe '#package!'

  describe "#procedure" do
    module Fake
      def self.stack_trace
        @stack ||= []
      end
      class Encryptor
        def encrypt_with
          Fake.stack_trace << :encryptor_before
          yield "encryption_command", ".enc"
          Fake.stack_trace << :encryptor_after
        end
      end
      class Splitter
        def split_with
          Fake.stack_trace << :splitter_before
          yield "splitter_command"
          Fake.stack_trace << :splitter_after
        end
      end
      class Package
        attr_accessor :trigger, :extension
        def basename
          "base_filename." + extension
        end
      end
    end

    let(:package)   { Fake::Package.new }
    let(:encryptor) { Fake::Encryptor.new }
    let(:splitter)  { Fake::Splitter.new }
    let(:pipeline)  { double }
    let(:s)         { sequence "" }

    before do
      Fake.stack_trace.clear
      expect(packager).to receive(:utility).with(:tar).and_return("tar")
      packager.instance_variable_set(:@package, package)
      packager.instance_variable_set(:@pipeline, pipeline)
      package.trigger = "model_trigger"
      package.extension = "tar"
    end

    context "when no encryptor or splitter are defined" do
      it "should package the backup without encryption into a single file" do
        expect(packager).to receive(:utility).with(:cat).and_return("cat")
        packager.instance_variable_set(:@encryptor, nil)
        packager.instance_variable_set(:@splitter,  nil)

        expect(pipeline).to receive(:add).ordered.with(
          "tar -cf - -C '#{Backup::Config.tmp_path}' 'model_trigger'", [0, 1]
        )
        expect(pipeline).to receive(:<<).ordered.with(
          "cat > #{File.join(Backup::Config.tmp_path, "base_filename.tar")}"
        )
        expect(pipeline).to receive(:run).ordered

        packager.send(:procedure).call
      end
    end

    context "when only an encryptor is configured" do
      it "should package the backup with encryption" do
        expect(packager).to receive(:utility).with(:cat).and_return("cat")
        packager.instance_variable_set(:@encryptor, encryptor)
        packager.instance_variable_set(:@splitter,  nil)

        expect(pipeline).to receive(:add).ordered.with(
          "tar -cf - -C '#{Backup::Config.tmp_path}' 'model_trigger'", [0, 1]
        )
        expect(pipeline).to receive(:<<).ordered.with("encryption_command")
        expect(pipeline).to receive(:<<).ordered.with(
          "cat > #{File.join(Backup::Config.tmp_path, "base_filename.tar.enc")}"
        )
        expect(pipeline).to receive(:run).ordered do
          Fake.stack_trace << :command_executed
          true
        end

        packager.send(:procedure).call

        expect(Fake.stack_trace).to eq([
          :encryptor_before, :command_executed, :encryptor_after
        ])
      end
    end

    context "when only a splitter is configured" do
      it "should package the backup without encryption through the splitter" do
        expect(packager).to receive(:utility).with(:cat).never
        packager.instance_variable_set(:@encryptor, nil)
        packager.instance_variable_set(:@splitter,  splitter)

        expect(pipeline).to receive(:add).ordered.with(
          "tar -cf - -C '#{Backup::Config.tmp_path}' 'model_trigger'", [0, 1]
        )
        expect(pipeline).to receive(:<<).ordered.with("splitter_command")

        expect(pipeline).to receive(:run).ordered do
          Fake.stack_trace << :command_executed
          true
        end

        packager.send(:procedure).call

        expect(Fake.stack_trace).to eq([
          :splitter_before, :command_executed, :splitter_after
        ])
      end
    end

    context "when both an encryptor and a splitter are configured" do
      it "should package the backup with encryption through the splitter" do
        expect(packager).to receive(:utility).with(:cat).never
        packager.instance_variable_set(:@encryptor, encryptor)
        packager.instance_variable_set(:@splitter,  splitter)

        expect(pipeline).to receive(:add).ordered.with(
          "tar -cf - -C '#{Backup::Config.tmp_path}' 'model_trigger'", [0, 1]
        )
        expect(pipeline).to receive(:<<).ordered.with("encryption_command")
        expect(pipeline).to receive(:<<).ordered.with("splitter_command")

        expect(pipeline).to receive(:run).ordered do
          Fake.stack_trace << :command_executed
          true
        end

        packager.send(:procedure).call

        expect(Fake.stack_trace).to eq([
          :encryptor_before, :splitter_before,
          :command_executed,
          :splitter_after, :encryptor_after
        ])
        expect(package.extension).to eq("tar.enc")
      end
    end
  end # describe '#procedure'
end
