require "spec_helper"

describe "Backup::Packager" do
  let(:packager) { Backup::Packager }

  it "should include Utilities::Helpers" do
    expect(packager.instance_eval("class << self; self; end")
      .include?(Backup::Utilities::Helpers)).to eq(true)
  end

  describe "#package!" do
    let(:model)     { mock }
    let(:package)   { mock }
    let(:encryptor) { mock }
    let(:splitter)  { mock }
    let(:pipeline)  { mock }
    let(:procedure) { mock }
    let(:s)         { sequence "" }

    context "when pipeline command is successful" do
      it "should setup variables and perform packaging procedures" do
        model.expects(:package).in_sequence(s).returns(package)
        model.expects(:encryptor).in_sequence(s).returns(encryptor)
        model.expects(:splitter).in_sequence(s).returns(splitter)
        Backup::Pipeline.expects(:new).in_sequence(s).returns(pipeline)

        Backup::Logger.expects(:info).in_sequence(s).with(
          "Packaging the backup files..."
        )
        packager.expects(:procedure).in_sequence(s).returns(procedure)
        procedure.expects(:call).in_sequence(s)

        pipeline.expects(:success?).in_sequence(s).returns(true)
        Backup::Logger.expects(:info).in_sequence(s).with(
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
        model.expects(:package).in_sequence(s).returns(package)
        model.expects(:encryptor).in_sequence(s).returns(encryptor)
        model.expects(:splitter).in_sequence(s).returns(splitter)
        Backup::Pipeline.expects(:new).in_sequence(s).returns(pipeline)

        Backup::Logger.expects(:info).in_sequence(s).with(
          "Packaging the backup files..."
        )
        packager.expects(:procedure).in_sequence(s).returns(procedure)
        procedure.expects(:call).in_sequence(s)

        pipeline.expects(:success?).in_sequence(s).returns(false)
        pipeline.expects(:error_messages).in_sequence(s).returns("pipeline_errors")

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
    let(:pipeline)  { mock }
    let(:s)         { sequence "" }

    before do
      Fake.stack_trace.clear
      packager.expects(:utility).with(:tar).returns("tar")
      packager.instance_variable_set(:@package, package)
      packager.instance_variable_set(:@pipeline, pipeline)
      package.trigger = "model_trigger"
      package.extension = "tar"
    end

    context "when no encryptor or splitter are defined" do
      it "should package the backup without encryption into a single file" do
        packager.expects(:utility).with(:cat).returns("cat")
        packager.instance_variable_set(:@encryptor, nil)
        packager.instance_variable_set(:@splitter,  nil)

        pipeline.expects(:add).in_sequence(s).with(
          "tar -cf - -C '#{Backup::Config.tmp_path}' 'model_trigger'", [0, 1]
        )
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > #{File.join(Backup::Config.tmp_path, "base_filename.tar")}"
        )
        pipeline.expects(:run).in_sequence(s)

        packager.send(:procedure).call
      end
    end

    context "when only an encryptor is configured" do
      it "should package the backup with encryption" do
        packager.expects(:utility).with(:cat).returns("cat")
        packager.instance_variable_set(:@encryptor, encryptor)
        packager.instance_variable_set(:@splitter,  nil)

        pipeline.expects(:add).in_sequence(s).with(
          "tar -cf - -C '#{Backup::Config.tmp_path}' 'model_trigger'", [0, 1]
        )
        pipeline.expects(:<<).in_sequence(s).with("encryption_command")
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > #{File.join(Backup::Config.tmp_path, "base_filename.tar.enc")}"
        )
        pipeline.expects(:run).in_sequence(s).with do
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
        packager.expects(:utility).with(:cat).never
        packager.instance_variable_set(:@encryptor, nil)
        packager.instance_variable_set(:@splitter,  splitter)

        pipeline.expects(:add).in_sequence(s).with(
          "tar -cf - -C '#{Backup::Config.tmp_path}' 'model_trigger'", [0, 1]
        )
        pipeline.expects(:<<).in_sequence(s).with("splitter_command")

        pipeline.expects(:run).in_sequence(s).with do
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
        packager.expects(:utility).with(:cat).never
        packager.instance_variable_set(:@encryptor, encryptor)
        packager.instance_variable_set(:@splitter,  splitter)

        pipeline.expects(:add).in_sequence(s).with(
          "tar -cf - -C '#{Backup::Config.tmp_path}' 'model_trigger'", [0, 1]
        )
        pipeline.expects(:<<).in_sequence(s).with("encryption_command")
        pipeline.expects(:<<).in_sequence(s).with("splitter_command")

        pipeline.expects(:run).in_sequence(s).with do
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
