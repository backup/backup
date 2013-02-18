# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Encryptor::Base do
  let(:base) { Backup::Encryptor::Base.new }

  it 'should include Utilities::Helpers' do
    Backup::Encryptor::Base.
      include?(Backup::Utilities::Helpers).should be_true
  end

  it 'should include Configuration::Helpers' do
    Backup::Encryptor::Base.
      include?(Backup::Configuration::Helpers).should be_true
  end

  describe '#initialize' do
    it 'should load defaults' do
      Backup::Encryptor::Base.any_instance.expects(:load_defaults!)
      base
    end
  end

  describe '#encryptor_name' do
    it 'should return class name with Backup namespace removed' do
      base.send(:encryptor_name).should == 'Encryptor::Base'
    end
  end

  describe '#log!' do
    it 'should log a message' do
      base.expects(:encryptor_name).returns('Encryptor Name')
      Backup::Logger.expects(:info).with(
        'Using Encryptor Name to encrypt the archive.'
      )
      base.send(:log!)
    end
  end
end
