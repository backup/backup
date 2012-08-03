# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::PostgreSQL do
  let(:model) { Backup::Model.new('foo', 'foo') }
  let(:db) do
    Backup::Database::PostgreSQL.new(model) do |db|
      db.name      = 'mydatabase'
      db.username  = 'someuser'
      db.password  = 'secret'
      db.host      = 'localhost'
      db.port      = '123'
      db.socket    = '/pgsql.sock'

      db.skip_tables = ['logs', 'profiles']
      db.only_tables = ['users', 'pirates']
      db.additional_options = ['--single-transaction', '--quick']
      db.pg_dump_utility    = '/path/to/pg_dump'
    end
  end

  it 'should be a subclass of Database::Base' do
    Backup::Database::PostgreSQL.superclass.
      should == Backup::Database::Base
  end

  describe '#initialize' do

    it 'should load pre-configured defaults through Base' do
      Backup::Database::PostgreSQL.any_instance.expects(:load_defaults!)
      db
    end

    it 'should pass the model reference to Base' do
      db.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      context 'when options are specified' do
        it 'should use the given values' do
          db.name.should      == 'mydatabase'
          db.username.should  == 'someuser'
          db.password.should  == 'secret'
          db.host.should      == 'localhost'
          db.port.should      == '123'
          db.socket.should    == '/pgsql.sock'

          db.skip_tables.should == ['logs', 'profiles']
          db.only_tables.should == ['users', 'pirates']
          db.additional_options.should == ['--single-transaction', '--quick']
          db.pg_dump_utility.should  == '/path/to/pg_dump'
        end
      end

      context 'when options are not specified' do
        before do
          Backup::Database::PostgreSQL.any_instance.expects(:utility).
              with(:pg_dump).returns('/real/pg_dump')
        end

        it 'should provide default values' do
          db = Backup::Database::PostgreSQL.new(model)

          db.name.should      be_nil
          db.username.should  be_nil
          db.password.should  be_nil
          db.host.should      be_nil
          db.port.should      be_nil
          db.socket.should    be_nil

          db.skip_tables.should         == []
          db.only_tables.should         == []
          db.additional_options.should  == []
          db.pg_dump_utility.should  == '/real/pg_dump'
        end
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Database::PostgreSQL.defaults do |db|
          db.name       = 'db_name'
          db.username   = 'db_username'
          db.password   = 'db_password'
          db.host       = 'db_host'
          db.port       = 789
          db.socket     = '/foo.sock'

          db.skip_tables = ['skip', 'tables']
          db.only_tables = ['only', 'tables']
          db.additional_options = ['--add', '--opts']
          db.pg_dump_utility  = '/default/path/to/pg_dump'
        end
      end

      after { Backup::Database::PostgreSQL.clear_defaults! }

      context 'when options are specified' do
        it 'should override the pre-configured defaults' do
          db.name.should      == 'mydatabase'
          db.username.should  == 'someuser'
          db.password.should  == 'secret'
          db.host.should      == 'localhost'
          db.port.should      == '123'
          db.socket.should    == '/pgsql.sock'

          db.skip_tables.should == ['logs', 'profiles']
          db.only_tables.should == ['users', 'pirates']
          db.additional_options.should == ['--single-transaction', '--quick']
          db.pg_dump_utility.should  == '/path/to/pg_dump'
        end
      end

      context 'when options are not specified' do
        it 'should use the pre-configured defaults' do
          db = Backup::Database::PostgreSQL.new(model)

          db.name.should      == 'db_name'
          db.username.should  == 'db_username'
          db.password.should  == 'db_password'
          db.host.should      == 'db_host'
          db.port.should      == 789
          db.socket.should    == '/foo.sock'

          db.skip_tables.should         == ['skip', 'tables']
          db.only_tables.should         == ['only', 'tables']
          db.additional_options.should  == ['--add', '--opts']
          db.pg_dump_utility.should   == '/default/path/to/pg_dump'
        end
      end
    end # context 'when no pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#perform!' do
    let(:s) { sequence '' }
    let(:pipeline) { mock }

    before do
      # superclass actions
      db.expects(:prepare!).in_sequence(s)
      db.expects(:log!).in_sequence(s)
      db.instance_variable_set(:@dump_path, '/dump/path')

      db.stubs(:pgdump).returns('pgdump_command')
      Backup::Pipeline.expects(:new).returns(pipeline)
    end

    context 'when no compressor is configured' do
      before do
        model.expects(:compressor).returns(nil)
      end

      it 'should run pgdump without compression' do
        pipeline.expects(:<<).in_sequence(s).with('pgdump_command')
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/dump/path/mydatabase.sql'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)
        Backup::Logger.expects(:message).in_sequence(s).with(
          'Database::PostgreSQL Complete!'
        )

        db.perform!
      end
    end

    context 'when a compressor is configured' do
      before do
        compressor = mock
        model.expects(:compressor).twice.returns(compressor)
        compressor.expects(:compress_with).yields('gzip', '.gz')
      end

      it 'should run pgdump with compression' do
        pipeline.expects(:<<).in_sequence(s).with('pgdump_command')
        pipeline.expects(:<<).in_sequence(s).with('gzip')
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/dump/path/mydatabase.sql.gz'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)
        Backup::Logger.expects(:message).in_sequence(s).with(
          'Database::PostgreSQL Complete!'
        )

        db.perform!
      end
    end

    context 'when pipeline command fails' do
      before do
        model.expects(:compressor).returns(nil)
        pipeline.stubs(:<<)
        pipeline.expects(:run)
        pipeline.expects(:success?).returns(false)
        pipeline.expects(:error_messages).returns('pipeline_errors')
      end

      it 'should raise an error' do
        expect do
          db.perform!
        end.to raise_error(
          Backup::Errors::Database::PipelineError,
          "Database::PipelineError: Database::PostgreSQL Dump Failed!\n" +
          "  pipeline_errors"
        )
      end
    end # context 'when pipeline command fails'

  end # describe '#perform!'

  describe '#pgdump' do
    it 'should return the pgdump command string' do
      db.send(:pgdump).should ==
        "PGPASSWORD='secret' /path/to/pg_dump --username='someuser' " +
        "--host='localhost' --port='123' --host='/pgsql.sock' " +
        "--single-transaction --quick --table='users' --table='pirates' " +
        "--exclude-table='logs' --exclude-table='profiles' mydatabase"
    end

    context 'without a password' do
      before { db.password = nil }
      it 'should not leave a preceeding space' do
        db.send(:pgdump).should ==
          "/path/to/pg_dump --username='someuser' " +
          "--host='localhost' --port='123' --host='/pgsql.sock' " +
          "--single-transaction --quick --table='users' --table='pirates' " +
          "--exclude-table='logs' --exclude-table='profiles' mydatabase"
      end
    end
  end

  describe '#password_options' do
    it 'returns the environment variable set for the password' do
      db.send(:password_options).should == "PGPASSWORD='secret' "
    end

    context 'when password is not set' do
      before { db.password = nil }
      it 'should return an empty string' do
        db.send(:password_options).should == ''
      end
    end
  end

  describe '#username_options' do
    it 'should return the postgresql syntax for the username options' do
      db.send(:username_options).should == "--username='someuser'"
    end

    context 'when username is not set' do
      before { db.username = nil }
      it 'should return an empty string' do
        db.send(:username_options).should == ''
      end
    end
  end

  describe '#connectivity_options' do
    it 'should return the postgresql syntax for the connectivity options' do
      db.send(:connectivity_options).should ==
        "--host='localhost' --port='123' --host='/pgsql.sock'"
    end

    context 'when only the socket is set' do
      before do
        db.host   = ''
        db.port   = nil
      end

      it 'should return only the socket' do
        db.send(:connectivity_options).should == "--host='/pgsql.sock'"
      end
    end
  end

  describe '#user_options' do
    it 'should return a string of additional options specified by the user' do
      db.send(:user_options).should == '--single-transaction --quick'
    end

    context 'when #additional_options is not set' do
      before { db.additional_options = [] }
      it 'should return an empty string' do
        db.send(:user_options).should == ''
      end
    end
  end

  describe '#tables_to_dump' do
    it 'should return a string for the pg_dump selected table to dump option' do
      db.send(:tables_to_dump).should == "--table='users' --table='pirates'"
    end

    context 'when #only_tables is not set' do
      before { db.only_tables = [] }
      it 'should return an empty string' do
        db.send(:tables_to_dump).should == ''
      end
    end
  end

  describe '#tables_to_skip' do
    it 'should return a string for the pg_dump --ignore-tables option' do
      db.send(:tables_to_skip).should == "--exclude-table='logs' --exclude-table='profiles'"
    end

    context 'when #skip_tables is not set' do
      before { db.skip_tables = [] }
      it 'should return an empty string' do
        db.send(:tables_to_skip).should == ''
      end
    end
  end

  describe 'deprecations' do
    describe '#utility_path' do
      before do
        Backup::Database::PostgreSQL.any_instance.stubs(:utility)
        Backup::Logger.expects(:warn).with {|err|
          err.should be_an_instance_of Backup::Errors::ConfigurationError
          err.message.should match(
            /Use PostgreSQL#pg_dump_utility instead/
          )
        }
      end
      after do
        Backup::Database::PostgreSQL.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          postgresql = Backup::Database::PostgreSQL.new(model) do |db|
            db.utility_path = 'foo'
          end
          postgresql.pg_dump_utility.should == 'foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          postgresql = Backup::Database::PostgreSQL.defaults do |db|
            db.utility_path = 'foo'
          end
          postgresql = Backup::Database::PostgreSQL.new(model)
          postgresql.pg_dump_utility.should == 'foo'
        end
      end
    end # describe '#utility_path'
  end
end
