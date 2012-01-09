# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::Base do
  let(:model) { Backup::Model.new('foo', 'foo') }
  let(:db) { Backup::Database::Base.new(model) }

  it 'should set #utility_path' do
    db.utility_path.should be_nil
    db.utility_path = 'utility path'
    db.utility_path.should == 'utility path'
  end

  describe '#perform!' do
    it 'should invoke prepare! and log!' do
      s = sequence ''
      db.expects(:prepare!).in_sequence(s)
      db.expects(:log!).in_sequence(s)

      db.perform!
    end
  end

  context 'since CLI::Helpers are included' do
    it 'should respond to the #utility method' do
      db.respond_to?(:utility).should be_true
    end
  end

  describe '#prepare!' do
    it 'should set and create #dump_path' do
      model = stub(:trigger => 'test_trigger')
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
      Backup::Logger.expects(:message).with(
        "Database::Base started dumping and archiving 'database_name'."
      )

      db.send(:log!)
    end
  end
end
