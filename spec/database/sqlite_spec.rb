# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Database::SQLite do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:db) do
    Database::SQLite.new(model) do |db|
      db.path      = '/tmp/db1.sqlite3'
      db.sqlitedump_utility  = '/path/to/sqlitedump'
    end
  end
  let(:s) { sequence '' }

  before do
    Database::SQLite.any_instance.stubs(:utility).
      with(:sqlitedump).returns('sqlitedump')
  end

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Database::Base'

  describe '#initialize' do

    it 'should load pre-configured defaults through Base' do
      Database::SQLite.any_instance.expects(:load_defaults!)
      db
    end

    it 'should pass the model reference to Base' do
      db.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      context 'when options are specified' do
        it 'should use the given values' do
          db.sqlitedump_utility.should  == '/path/to/sqlitedump'
        end
      end

    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Database::SQLite.defaults do |db|
          db.sqlitedump_utility  = '/default/path/to/sqlitedump'
        end
      end

      after { Database::SQLite.clear_defaults! }

      context 'when options are specified' do
        it 'should override the pre-configured defaults' do
          db.sqlitedump_utility.should  == '/path/to/sqlitedump'
        end
      end

      context 'when options are not specified' do
        it 'should use the pre-configured defaults' do
          db = Database::SQLite.new(model)

          db.sqlitedump_utility.should   == '/default/path/to/sqlitedump'
        end
      end
    end # context 'when no pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#perform!' do
    let(:pipeline) { mock }
    let(:compressor) { mock }

    before do
      # superclass actions
      db.instance_variable_set(:@dump_path, '/dump/path')
      db.stubs(:dump_filename).returns('dump_filename')

      db.expects(:log!).in_sequence(s).with(:started)
      db.expects(:prepare!).in_sequence(s)
    end

    context 'when no compressor is configured' do
      it 'should run sqlitedump without compression' do

        Pipeline.expects(:new).returns(pipeline)
        pipeline.expects(:<<).in_sequence(s).with("echo '.dump' | /path/to/sqlitedump /tmp/db1.sqlite3")
        model.expects(:compressor).returns(nil)
        pipeline.expects(:<<).in_sequence(s).with("cat > '/dump/path/dump_filename.sql'")

        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end
    end

    context 'when a compressor is configured' do

      it 'should run sqlitedump with compression' do

        Pipeline.expects(:new).returns(pipeline)
        pipeline.expects(:<<).in_sequence(s).with("echo '.dump' | /path/to/sqlitedump /tmp/db1.sqlite3")
        model.expects(:compressor).twice.returns(compressor)
        compressor.expects(:compress_with).yields('gzip', '.gz')
        pipeline.expects(:<<).in_sequence(s).with('gzip')
        pipeline.expects(:<<).in_sequence(s).with("cat > '/dump/path/dump_filename.sql.gz'")

        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end
    end

    context 'when pipeline command fails' do
      before do
        Pipeline.expects(:new).returns(pipeline)
        pipeline.expects(:<<).in_sequence(s).with("echo '.dump' | /path/to/sqlitedump /tmp/db1.sqlite3")
        model.expects(:compressor).returns(nil)
        pipeline.expects(:<<).in_sequence(s).with("cat > '/dump/path/dump_filename.sql'")
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(false)
        pipeline.expects(:error_messages).returns('pipeline_errors')
      end

      it 'should raise an error' do
        expect do
          db.perform!
        end.to raise_error(
          Database::SQLite::Error,
          "Database::SQLite::Error: Database::SQLite Dump Failed!\n" +
          "  pipeline_errors"
        )
      end
    end # context 'when pipeline command fails'

  end # describe '#perform!'

end
end
