# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::MySQL do
  let(:model) { Backup::Model.new('foo', 'foo') }
  let(:db) do
    Backup::Database::MySQL.new(model) do |db|
      db.name      = 'mydatabase'
      db.username  = 'someuser'
      db.password  = 'secret'
      db.host      = 'localhost'
      db.port      = '123'
      db.socket    = '/mysql.sock'

      db.skip_tables = ['logs', 'profiles']
      db.only_tables = ['users', 'pirates']
      db.additional_options = ['--single-transaction', '--quick']
      db.mysqldump_utility  = '/path/to/mysqldump'
    end
  end

  it 'should be a subclass of Database::Base' do
    Backup::Database::MySQL.superclass.
      should == Backup::Database::Base
  end

  describe '#initialize' do

    it 'should load pre-configured defaults through Base' do
      Backup::Database::MySQL.any_instance.expects(:load_defaults!)
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
          db.socket.should    == '/mysql.sock'

          db.skip_tables.should == ['logs', 'profiles']
          db.only_tables.should == ['users', 'pirates']
          db.additional_options.should == ['--single-transaction', '--quick']
          db.mysqldump_utility.should  == '/path/to/mysqldump'
        end
      end

      context 'when options are not specified' do
        before do
          Backup::Database::MySQL.any_instance.expects(:utility).
              with(:mysqldump).returns('/real/mysqldump')
        end

        it 'should provide default values' do
          db = Backup::Database::MySQL.new(model)

          db.name.should      == :all
          db.username.should  be_nil
          db.password.should  be_nil
          db.host.should      be_nil
          db.port.should      be_nil
          db.socket.should    be_nil

          db.skip_tables.should         == []
          db.only_tables.should         == []
          db.additional_options.should  == []
          db.mysqldump_utility.should  == '/real/mysqldump'
        end
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Database::MySQL.defaults do |db|
          db.name       = 'db_name'
          db.username   = 'db_username'
          db.password   = 'db_password'
          db.host       = 'db_host'
          db.port       = 789
          db.socket     = '/foo.sock'

          db.skip_tables = ['skip', 'tables']
          db.only_tables = ['only', 'tables']
          db.additional_options = ['--add', '--opts']
          db.mysqldump_utility  = '/default/path/to/mysqldump'
        end
      end

      after { Backup::Database::MySQL.clear_defaults! }

      context 'when options are specified' do
        it 'should override the pre-configured defaults' do
          db.name.should      == 'mydatabase'
          db.username.should  == 'someuser'
          db.password.should  == 'secret'
          db.host.should      == 'localhost'
          db.port.should      == '123'
          db.socket.should    == '/mysql.sock'

          db.skip_tables.should == ['logs', 'profiles']
          db.only_tables.should == ['users', 'pirates']
          db.additional_options.should == ['--single-transaction', '--quick']
          db.mysqldump_utility.should  == '/path/to/mysqldump'
        end
      end

      context 'when options are not specified' do
        it 'should use the pre-configured defaults' do
          db = Backup::Database::MySQL.new(model)

          db.name.should      == 'db_name'
          db.username.should  == 'db_username'
          db.password.should  == 'db_password'
          db.host.should      == 'db_host'
          db.port.should      == 789
          db.socket.should    == '/foo.sock'

          db.skip_tables.should         == ['skip', 'tables']
          db.only_tables.should         == ['only', 'tables']
          db.additional_options.should  == ['--add', '--opts']
          db.mysqldump_utility.should   == '/default/path/to/mysqldump'
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

      db.stubs(:mysqldump).returns('mysqldump_command')
      db.stubs(:dump_filename).returns('dump_filename')
      Backup::Pipeline.expects(:new).returns(pipeline)
    end

    context 'when no compressor is configured' do
      before do
        model.expects(:compressor).returns(nil)
      end

      it 'should run mysqldump without compression' do
        pipeline.expects(:<<).in_sequence(s).with('mysqldump_command')
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/dump/path/dump_filename.sql'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)
        Backup::Logger.expects(:message).in_sequence(s).with(
          'Database::MySQL Complete!'
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

      it 'should run mysqldump with compression' do
        pipeline.expects(:<<).in_sequence(s).with('mysqldump_command')
        pipeline.expects(:<<).in_sequence(s).with('gzip')
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/dump/path/dump_filename.sql.gz'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)
        Backup::Logger.expects(:message).in_sequence(s).with(
          'Database::MySQL Complete!'
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
          "Database::PipelineError: Database::MySQL Dump Failed!\n" +
          "  pipeline_errors"
        )
      end
    end # context 'when pipeline command fails'

  end # describe '#perform!'

  describe '#mysqldump' do
    before do
      db.stubs(:mysqldump_utility).returns(:mysqldump_utility)
      db.stubs(:credential_options).returns(:credential_options)
      db.stubs(:connectivity_options).returns(:connectivity_options)
      db.stubs(:user_options).returns(:user_options)
      db.stubs(:db_name).returns(:db_name)
      db.stubs(:tables_to_dump).returns(:tables_to_dump)
      db.stubs(:tables_to_skip).returns(:tables_to_skip)
    end

    it 'should return the mysqldump command string' do
      db.send(:mysqldump).should ==
        "mysqldump_utility credential_options connectivity_options " +
        "user_options db_name tables_to_dump tables_to_skip"
    end
  end

  describe '#dump_filename' do
    context 'when @name is set to :all' do
      before { db.name = :all }
      it 'should set the filename to "all-databases"' do
        db.send(:dump_filename).should == 'all-databases'
      end
    end

    context 'when @name is not set to :all' do
      it 'should return @name' do
        db.send(:dump_filename).should == 'mydatabase'
      end
    end
  end

  describe '#credential_options' do
    context 'when a password is set' do
      it 'should return the command string for the user credentials' do
        db.send(:credential_options).should ==
          "--user='someuser' --password='secret'"
      end
    end

    context 'when no password is set' do
      before { db.password = nil }
      it 'should return the command string for the user credentials' do
        db.send(:credential_options).should ==
          "--user='someuser'"
      end
    end
  end

  describe '#connectivity_options' do
    it 'should return the mysql syntax for the connectivity options' do
      db.send(:connectivity_options).should ==
        "--host='localhost' --port='123' --socket='/mysql.sock'"
    end

    context 'when only the socket is set' do
      it 'should return only the socket' do
        db.host   = ''
        db.port   = nil
        db.send(:connectivity_options).should == "--socket='/mysql.sock'"
      end
    end

    context 'when only the host and port are set' do
      it 'should return only the host and port' do
        db.socket = nil
        db.send(:connectivity_options).should ==
          "--host='localhost' --port='123'"
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

  describe '#db_name' do
    context 'when @name is set to :all' do
      before { db.name = :all }
      it 'should return the mysqldump flag to dump all databases' do
        db.send(:db_name).should == '--all-databases'
      end
    end

    context 'when @name is not set to :all' do
      it 'should return @name' do
        db.send(:db_name).should == 'mydatabase'
      end
    end
  end

  describe '#tables_to_dump' do
    it 'should return a string for the mysqldump selected table to dump option' do
      db.send(:tables_to_dump).should == 'users pirates'
    end

    context 'when #only_tables is not set' do
      before { db.only_tables = [] }
      it 'should return an empty string' do
        db.send(:tables_to_dump).should == ''
      end
    end

    context 'when dump_all? is true' do
      before { db.stubs(:dump_all?).returns(true) }
      it 'should return nil' do
        db.send(:tables_to_dump).should be_nil
      end
    end
  end

  describe '#tables_to_skip' do
    it 'should return a string for the mysqldump --ignore-tables option' do
      db.send(:tables_to_skip).should ==
        "--ignore-table='mydatabase.logs' --ignore-table='mydatabase.profiles'"
    end

    it 'should return an empty string if #skip_tables is empty' do
      db.skip_tables = []
      db.send(:tables_to_skip).should == ''
    end

    it 'should accept table names prefixed with the database name' do
      db.skip_tables = ['table_name', 'db_name.table_name']
      db.send(:tables_to_skip).should ==
        "--ignore-table='mydatabase.table_name' --ignore-table='db_name.table_name'"
    end

    it 'should not prefix table name if dump_all? is true' do
      db.name = :all
      db.skip_tables = ['table_name', 'db_name.table_name']
      db.send(:tables_to_skip).should ==
        "--ignore-table='table_name' --ignore-table='db_name.table_name'"
    end
  end

  describe '#dump_all?' do
    context 'when @name is set to :all' do
      before { db.name = :all }
      it 'should return true' do
        db.send(:dump_all?).should be_true
      end
    end

    context 'when @name is not set to :all' do
      it 'should return false' do
        db.send(:dump_all?).should be_false
      end
    end
  end

  describe 'deprecations' do
    describe '#utility_path' do
      before do
        Backup::Database::MySQL.any_instance.stubs(:utility)
        Backup::Logger.expects(:warn).with {|err|
          err.should be_an_instance_of Backup::Errors::ConfigurationError
          err.message.should match(
            /Use MySQL#mysqldump_utility instead/
          )
        }
      end
      after do
        Backup::Database::MySQL.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          mysql = Backup::Database::MySQL.new(model) do |db|
            db.utility_path = 'foo'
          end
          mysql.mysqldump_utility.should == 'foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          mysql = Backup::Database::MySQL.defaults do |db|
            db.utility_path = 'foo'
          end
          mysql = Backup::Database::MySQL.new(model)
          mysql.mysqldump_utility.should == 'foo'
        end
      end
    end # describe '#utility_path'
  end
end
