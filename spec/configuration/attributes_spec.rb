require 'backup/configuration/attributes'

describe Backup::Configuration::Attributes do
  before(:all) do
    class ConfigurationSample
      extend Backup::Configuration::Attributes
      generate_attributes :file, :username, :password
    end
    @sample = ConfigurationSample.new
  end
  
  it "should generate setter methods to attributes" do
    @sample.should respond_to(:file)
    @sample.should respond_to(:username)
    @sample.should respond_to(:password)
  end
  
  it "should generate accessor for attributes" do
    @sample.should respond_to(:attributes)
  end
  
  it "should store keys of attributes as strings" do
    @sample.file "list.txt"
    @sample.username "jonh"
    @sample.password "secret"
    @sample.attributes.keys.all? {|k| k.is_a?(String)}.should == true
  end
  
  it "should store values of attributes in attributes hash" do
    @sample.file "list.txt"
    @sample.attributes.keys.should include('file')
    @sample.attributes['file'].should == "list.txt"
  end
end

