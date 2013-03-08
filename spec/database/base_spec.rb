# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::Base do
  let(:model) { Backup::Model.new('test_trigger', 'foo') }
  let(:db) { Backup::Database::Base.new(model) }

  it 'should include Utilities::Helpers' do
    Backup::Database::Base.
      include?(Backup::Utilities::Helpers).should be_true
  end

  it 'should include Configuration::Helpers' do
    Backup::Database::Base.
      include?(Backup::Configuration::Helpers).should be_true
  end

  describe '#initialize' do
    it 'should load pre-configured defaults' do
      Backup::Database::Base.any_instance.expects(:load_defaults!)
      db
    end

    it 'should set a reference to the model' do
      db.instance_variable_get(:@model).should == model
    end
  end

  describe '#perform!' do
    it 'should invoke prepare! and log!' do
      s = sequence ''
      db.expects(:prepare!).in_sequence(s)
      db.expects(:log!).in_sequence(s)

      db.perform!
    end
  end

  describe '#prepare!' do
    it 'should set and create #dump_path' do
      db.instance_variable_set(:@model, model)
      FileUtils.expects(:mkdir_p).with(
        File.join(Backup::Config.tmp_path, 'test_trigger', 'databases', 'Base')
      )
      db.send(:prepare!)
      db.instance_variable_get(:@dump_path).should ==
        File.join(Backup::Config.tmp_path, 'test_trigger', 'databases', 'Base')
    end
  end

  describe '#log!' do
    it 'should use #database_name' do
      db.stubs(:name).returns('database_name')
      Backup::Logger.expects(:info).with(
        "Database::Base started dumping and archiving 'database_name'."
      )

      db.send(:log!)
    end
  end
end
