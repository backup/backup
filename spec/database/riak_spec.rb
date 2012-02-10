# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::Riak do
  let(:model) { Backup::Model.new('foo', 'foo') }
  let(:db) do
    Backup::Database::Riak.new(model) do |db|
      db.name         = 'mydatabase'
      db.node         = 'riak@localhost'
      db.cookie       = 'riak'
      db.riak_admin_utility = '/path/to/riak-admin'
    end
  end

  describe '#initialize' do
    it 'should read the adapter details correctly' do
      db.name.should      == 'mydatabase'
      db.node.should      == 'riak@localhost'
      db.cookie.should    == 'riak'
      db.riak_admin_utility.should == '/path/to/riak-admin'
    end

    context 'when options are not set' do
      before do
        Backup::Database::Riak.any_instance.expects(:utility).
            with('riak-admin').returns('/real/riak-admin')
      end

      it 'should use default values' do
        db = Backup::Database::Riak.new(model)

        db.name.should        be_nil
        db.node.should        be_nil
        db.cookie.should      be_nil
        db.riak_admin_utility.should == '/real/riak-admin'
      end
    end

    context 'when configuration defaults have been set' do
      after { Backup::Configuration::Database::Riak.clear_defaults! }

      it 'should use configuration defaults' do
        Backup::Configuration::Database::Riak.defaults do |db|
          db.name         = 'db_name'
          db.node         = 'db_node'
          db.cookie       = 'db_cookie'
          db.riak_admin_utility = '/default/path/to/riak-admin'
        end

        db = Backup::Database::Riak.new(model)
        db.name.should        == 'db_name'
        db.node.should        == 'db_node'
        db.cookie.should      == 'db_cookie'
        db.riak_admin_utility.should == '/default/path/to/riak-admin'
      end
    end
  end # describe '#initialize'

  describe '#perform!' do
    let(:compressor) { mock }
    let(:s) { sequence '' }
    before do
      # superclass actions
      db.expects(:prepare!).in_sequence(s)
      db.expects(:log!).in_sequence(s)
      db.instance_variable_set(:@dump_path, '/dump/path')

      db.stubs(:riakadmin).returns('riakadmin_command')
    end

    context 'when no compressor is configured' do
      it 'should only perform the riak-admin backup command' do
        FileUtils.expects(:chown_R).with('riak', 'riak', '/dump/path')
        db.expects(:run).in_sequence(s).
            with('riakadmin_command /dump/path/mydatabase node')

        db.perform!
      end
    end

    context 'when a compressor is configured' do
      before do
        model.stubs(:compressor).returns(compressor)
        compressor.expects(:compress_with).yields('compressor_command', '.gz')
      end

      it 'should compress the backup file and remove the source file' do
        FileUtils.expects(:chown_R).with('riak', 'riak', '/dump/path')
        db.expects(:run).in_sequence(s).
            with('riakadmin_command /dump/path/mydatabase node')
        db.expects(:run).in_sequence(s).with(
          "compressor_command -c /dump/path/mydatabase > /dump/path/mydatabase.gz"
        )
        FileUtils.expects(:rm_f).in_sequence(s).with('/dump/path/mydatabase')

        db.perform!
      end
    end
  end

  describe '#riakadmin' do
    it 'should return the full riakadmin string' do
      db.send(:riakadmin).should == "/path/to/riak-admin backup riak@localhost riak"
    end
  end

end
