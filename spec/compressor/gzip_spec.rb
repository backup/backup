require "spec_helper"

describe Backup::Compressor::Gzip do
  before do
    Backup::Compressor::Gzip.stubs(:utility).returns("gzip")
    Backup::Compressor::Gzip.instance_variable_set(:@has_rsyncable, true)
    Backup::Compressor::Gzip.any_instance.stubs(:utility).returns("gzip")
  end

  it "should be a subclass of Compressor::Base" do
    expect(Backup::Compressor::Gzip
      .superclass).to eq(Backup::Compressor::Base)
  end

  it "should be extended by Utilities::Helpers" do
    expect(Backup::Compressor::Gzip.instance_eval("class << self; self; end"))
      .to include(Backup::Utilities::Helpers)
  end

  describe ".has_rsyncable?" do
    before do
      Backup::Compressor::Gzip.instance_variable_set(:@has_rsyncable, nil)
    end

    context "when --rsyncable is available" do
      before do
        Backup::Compressor::Gzip.expects(:`).once
          .with("gzip --rsyncable --version >/dev/null 2>&1; echo $?")
          .returns("0\n")
      end

      it "returns true and caches the result" do
        expect(Backup::Compressor::Gzip.has_rsyncable?).to be(true)
        expect(Backup::Compressor::Gzip.has_rsyncable?).to be(true)
      end
    end

    context "when --rsyncable is not available" do
      before do
        Backup::Compressor::Gzip.expects(:`).once
          .with("gzip --rsyncable --version >/dev/null 2>&1; echo $?")
          .returns("1\n")
      end

      it "returns false and caches the result" do
        expect(Backup::Compressor::Gzip.has_rsyncable?).to be(false)
        expect(Backup::Compressor::Gzip.has_rsyncable?).to be(false)
      end
    end
  end

  describe "#initialize" do
    let(:compressor) { Backup::Compressor::Gzip.new }

    after { Backup::Compressor::Gzip.clear_defaults! }

    context "when no pre-configured defaults have been set" do
      it "should use default values" do
        expect(compressor.level).to be(false)
        expect(compressor.rsyncable).to be(false)

        compressor.compress_with do |cmd, ext|
          expect(cmd).to eq("gzip")
          expect(ext).to eq(".gz")
        end
      end

      it "should use the values given" do
        compressor = Backup::Compressor::Gzip.new do |c|
          c.level = 5
          c.rsyncable = true
        end
        expect(compressor.level).to eq(5)
        expect(compressor.rsyncable).to be(true)

        compressor.compress_with do |cmd, ext|
          expect(cmd).to eq("gzip -5 --rsyncable")
          expect(ext).to eq(".gz")
        end
      end
    end # context 'when no pre-configured defaults have been set'

    context "when pre-configured defaults have been set" do
      before do
        Backup::Compressor::Gzip.defaults do |c|
          c.level = 7
          c.rsyncable = true
        end
      end

      it "should use pre-configured defaults" do
        expect(compressor.level).to eq(7)
        expect(compressor.rsyncable).to be(true)

        compressor.compress_with do |cmd, ext|
          expect(cmd).to eq("gzip -7 --rsyncable")
          expect(ext).to eq(".gz")
        end
      end

      it "should override pre-configured defaults" do
        compressor = Backup::Compressor::Gzip.new do |c|
          c.level = 6
          c.rsyncable = false
        end
        expect(compressor.level).to eq(6)
        expect(compressor.rsyncable).to be(false)

        compressor.compress_with do |cmd, ext|
          expect(cmd).to eq("gzip -6")
          expect(ext).to eq(".gz")
        end
      end
    end # context 'when pre-configured defaults have been set'

    it "should ignore rsyncable option and warn user if not supported" do
      Backup::Compressor::Gzip.instance_variable_set(:@has_rsyncable, false)

      Backup::Logger.expects(:warn).with do |err|
        expect(err).to be_a(Backup::Compressor::Gzip::Error)
        expect(err.message).to match(/'rsyncable' option ignored/)
      end

      compressor = Backup::Compressor::Gzip.new do |c|
        c.level = 5
        c.rsyncable = true
      end
      expect(compressor.level).to eq(5)
      expect(compressor.rsyncable).to be(true)

      compressor.compress_with do |cmd, ext|
        expect(cmd).to eq("gzip -5")
        expect(ext).to eq(".gz")
      end
    end
  end # describe '#initialize'
end
