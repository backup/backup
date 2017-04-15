require "spec_helper"

describe Backup::Compressor::Base do
  let(:compressor) { Backup::Compressor::Base.new }

  it "should include Utilities::Helpers" do
    expect(Backup::Compressor::Base
      .include?(Backup::Utilities::Helpers)).to eq(true)
  end

  it "should include Config::Helpers" do
    expect(Backup::Compressor::Base
      .include?(Backup::Config::Helpers)).to eq(true)
  end

  describe "#compress_with" do
    it "should yield the compressor command and extension" do
      compressor.instance_variable_set(:@cmd, "compressor command")
      compressor.instance_variable_set(:@ext, "compressor extension")

      compressor.expects(:log!)

      compressor.compress_with do |cmd, ext|
        expect(cmd).to eq("compressor command")
        expect(ext).to eq("compressor extension")
      end
    end
  end

  describe "#compressor_name" do
    it "should return class name with Backup namespace removed" do
      expect(compressor.send(:compressor_name)).to eq("Compressor::Base")
    end
  end

  describe "#log!" do
    it "should log a message" do
      compressor.instance_variable_set(:@cmd, "compressor command")
      compressor.instance_variable_set(:@ext, "compressor extension")
      compressor.expects(:compressor_name).returns("Compressor Name")

      Backup::Logger.expects(:info).with(
        "Using Compressor Name for compression.\n" \
        "  Command: 'compressor command'\n" \
        "  Ext: 'compressor extension'"
      )
      compressor.send(:log!)
    end
  end
end
