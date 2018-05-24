require "spec_helper"

describe Backup::Compressor::Custom do
  let(:compressor) { Backup::Compressor::Custom.new }

  before(:context) do
    # Utilities::Helpers#utility will raise an error
    # if the command is invalid or not set
    Backup::Compressor::Custom.send(
      :define_method, :utility,
      ->(arg) { arg.to_s.empty? ? "error" : "/path/to/#{arg}" }
    )
  end

  it "should be a subclass of Compressor::Base" do
    expect(Backup::Compressor::Custom
      .superclass).to eq(Backup::Compressor::Base)
  end

  describe "#initialize" do
    let(:compressor) { Backup::Compressor::Custom.new }

    after { Backup::Compressor::Custom.clear_defaults! }

    it "should load pre-configured defaults" do
      Backup::Compressor::Custom.any_instance.expects(:load_defaults!)
      compressor
    end

    it "should call Utilities::Helpers#utility to validate command" do
      Backup::Compressor::Custom.any_instance.expects(:utility)
      compressor
    end

    it "should clean the command and extension for use with compress_with" do
      compressor = Backup::Compressor::Custom.new do |c|
        c.command   = " my_command --option foo "
        c.extension = " my_extension "
      end

      expect(compressor.command).to   eq(" my_command --option foo ")
      expect(compressor.extension).to eq(" my_extension ")

      compressor.expects(:log!)
      compressor.compress_with do |cmd, ext|
        expect(cmd).to eq("/path/to/my_command --option foo")
        expect(ext).to eq("my_extension")
      end
    end

    context "when no pre-configured defaults have been set" do
      it "should use default values" do
        expect(compressor.command).to   be_nil
        expect(compressor.extension).to be_nil

        expect(compressor.instance_variable_get(:@cmd)).to eq("error")
        expect(compressor.instance_variable_get(:@ext)).to eq("")
      end

      it "should use the values given" do
        compressor = Backup::Compressor::Custom.new do |c|
          c.command   = "my_command"
          c.extension = "my_extension"
        end

        expect(compressor.command).to   eq("my_command")
        expect(compressor.extension).to eq("my_extension")

        expect(compressor.instance_variable_get(:@cmd)).to eq("/path/to/my_command")
        expect(compressor.instance_variable_get(:@ext)).to eq("my_extension")
      end
    end # context 'when no pre-configured defaults have been set'

    context "when pre-configured defaults have been set" do
      before do
        Backup::Compressor::Custom.defaults do |c|
          c.command   = "default_command"
          c.extension = "default_extension"
        end
      end

      it "should use pre-configured defaults" do
        expect(compressor.command).to   eq("default_command")
        expect(compressor.extension).to eq("default_extension")

        expect(compressor.instance_variable_get(:@cmd)).to eq("/path/to/default_command")
        expect(compressor.instance_variable_get(:@ext)).to eq("default_extension")
      end

      it "should override pre-configured defaults" do
        compressor = Backup::Compressor::Custom.new do |c|
          c.command   = "new_command"
          c.extension = "new_extension"
        end

        expect(compressor.command).to   eq("new_command")
        expect(compressor.extension).to eq("new_extension")

        expect(compressor.instance_variable_get(:@cmd)).to eq("/path/to/new_command")
        expect(compressor.instance_variable_get(:@ext)).to eq("new_extension")
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'
end
