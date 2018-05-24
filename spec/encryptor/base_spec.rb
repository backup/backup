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
      Backup::Encryptor::Base.any_instance.expects(:load_defaults!)
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
      base.expects(:encryptor_name).returns("Encryptor Name")
      Backup::Logger.expects(:info).with(
        "Using Encryptor Name to encrypt the archive."
      )
      base.send(:log!)
    end
  end
end
