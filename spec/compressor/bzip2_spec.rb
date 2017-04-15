require "spec_helper"

describe Backup::Compressor::Bzip2 do
  before do
    Backup::Compressor::Bzip2.any_instance.stubs(:utility).returns("bzip2")
  end

  it "should be a subclass of Compressor::Base" do
    expect(Backup::Compressor::Bzip2
      .superclass).to eq(Backup::Compressor::Base)
  end

  describe "#initialize" do
    let(:compressor) { Backup::Compressor::Bzip2.new }

    after { Backup::Compressor::Bzip2.clear_defaults! }

    it "should load pre-configured defaults" do
      Backup::Compressor::Bzip2.any_instance.expects(:load_defaults!)
      compressor
    end

    context "when no pre-configured defaults have been set" do
      it "should use default values" do
        expect(compressor.level).to eq(false)

        expect(compressor.instance_variable_get(:@cmd)).to eq("bzip2")
        expect(compressor.instance_variable_get(:@ext)).to eq(".bz2")
      end

      it "should use the values given" do
        compressor = Backup::Compressor::Bzip2.new do |c|
          c.level = 5
        end
        expect(compressor.level).to eq(5)

        expect(compressor.instance_variable_get(:@cmd)).to eq("bzip2 -5")
        expect(compressor.instance_variable_get(:@ext)).to eq(".bz2")
      end
    end # context 'when no pre-configured defaults have been set'

    context "when pre-configured defaults have been set" do
      before do
        Backup::Compressor::Bzip2.defaults do |c|
          c.level = 7
        end
      end

      it "should use pre-configured defaults" do
        expect(compressor.level).to eq(7)

        expect(compressor.instance_variable_get(:@cmd)).to eq("bzip2 -7")
        expect(compressor.instance_variable_get(:@ext)).to eq(".bz2")
      end

      it "should override pre-configured defaults" do
        compressor = Backup::Compressor::Bzip2.new do |c|
          c.level = 6
        end
        expect(compressor.level).to eq(6)

        expect(compressor.instance_variable_get(:@cmd)).to eq("bzip2 -6")
        expect(compressor.instance_variable_get(:@ext)).to eq(".bz2")
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'
end
