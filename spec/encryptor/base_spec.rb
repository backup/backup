require "spec_helper"

describe Backup::Encryptor::Base do
  let(:base) { Backup::Encryptor::Base.new }

  it "should include Utilities::Helpers" do
    expect(Backup::Encryptor::Base
      .include?(Backup::Utilities::Helpers)).to eq(true)
  end

  it "should include Config::Helpers" do
    expect(Backup::Encryptor::Base
      .include?(Backup::Config::Helpers)).to eq(true)
  end

  describe "#initialize" do
    it "should load defaults" do
      expect_any_instance_of(Backup::Encryptor::Base).to receive(:load_defaults!)
      base
    end
  end

  describe "#encryptor_name" do
    it "should return class name with Backup namespace removed" do
      expect(base.send(:encryptor_name)).to eq("Encryptor::Base")
    end
  end

  describe "#log!" do
    it "should log a message" do
      expect(base).to receive(:encryptor_name).and_return("Encryptor Name")
      expect(Backup::Logger).to receive(:info).with(
        "Using Encryptor Name to encrypt the archive."
      )
      base.send(:log!)
    end
  end
end
