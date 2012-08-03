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

  it 'should be a subclass of Database::Base' do
    Backup::Database::Riak.superclass.
      should == Backup::Database::Base
  end

  describe '#initialize' do

    it 'should load pre-configured defaults through Base' do
      Backup::Database::Riak.any_instance.expects(:load_defaults!)
      db
    end

    it 'should pass the model reference to Base' do
      db.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      context 'when options are specified' do
        it 'should use the given values' do
          db.name.should      == 'mydatabase'
          db.node.should      == 'riak@localhost'
          db.cookie.should    == 'riak'
          db.riak_admin_utility.should == '/path/to/riak-admin'
        end
      end

      context 'when options are not specified' do
        before do
          Backup::Database::Riak.any_instance.expects(:utility).
              with('riak-admin').returns('/real/riak-admin')
        end

        it 'should provide default values' do
          db = Backup::Database::Riak.new(model)

          db.name.should        be_nil
          db.node.should        be_nil
          db.cookie.should      be_nil
          db.riak_admin_utility.should == '/real/riak-admin'
        end
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Database::Riak.defaults do |db|
          db.name         = 'db_name'
          db.node         = 'db_node'
          db.cookie       = 'db_cookie'
          db.riak_admin_utility = '/default/path/to/riak-admin'
        end
      end

      after { Backup::Database::Riak.clear_defaults! }

      context 'when options are specified' do
        it 'should override the pre-configured defaults' do
          db.name.should      == 'mydatabase'
          db.node.should      == 'riak@localhost'
          db.cookie.should    == 'riak'
          db.riak_admin_utility.should == '/path/to/riak-admin'
        end
      end

      context 'when options are not specified' do
        it 'should use the pre-configured defaults' do
          db = Backup::Database::Riak.new(model)

          db.name.should        == 'db_name'
          db.node.should        == 'db_node'
          db.cookie.should      == 'db_cookie'
          db.riak_admin_utility.should == '/default/path/to/riak-admin'
        end
      end
    end # context 'when no pre-configured defaults have been set'
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

  describe 'deprecations' do
    describe '#utility_path' do
      before do
        Backup::Database::Riak.any_instance.stubs(:utility)
        Backup::Logger.expects(:warn).with {|err|
          err.should be_an_instance_of Backup::Errors::ConfigurationError
          err.message.should match(
            /Use Riak#riak_admin_utility instead/
          )
        }
      end
      after do
        Backup::Database::Riak.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          riak = Backup::Database::Riak.new(model) do |db|
            db.utility_path = 'foo'
          end
          riak.riak_admin_utility.should == 'foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          riak = Backup::Database::Riak.defaults do |db|
            db.utility_path = 'foo'
          end
          riak = Backup::Database::Riak.new(model)
          riak.riak_admin_utility.should == 'foo'
        end
      end
    end # describe '#utility_path'
  end
end
