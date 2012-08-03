# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::MongoDB do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:db) do
    Backup::Database::MongoDB.new(model) do |db|
      db.name      = 'mydatabase'
      db.username  = 'someuser'
      db.password  = 'secret'
      db.host      = 'localhost'
      db.port      = 123

      db.ipv6               = true
      db.only_collections   = ['users', 'pirates']
      db.additional_options = ['--query', '--foo']
      db.mongodump_utility  = '/path/to/mongodump'
      db.mongo_utility      = '/path/to/mongo'
      db.lock               = true
    end
  end

  it 'should be a subclass of Database::Base' do
    Backup::Database::MongoDB.superclass.
      should == Backup::Database::Base
  end

  describe '#initialize' do

    it 'should load pre-configured defaults through Base' do
      Backup::Database::MongoDB.any_instance.expects(:load_defaults!)
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
          db.port.should      == 123

          db.ipv6.should                == true
          db.only_collections.should    == ['users', 'pirates']
          db.additional_options.should  == ['--query', '--foo']
          db.mongodump_utility.should   == '/path/to/mongodump'
          db.mongo_utility.should       == '/path/to/mongo'
          db.lock.should                == true
        end
      end

      context 'when options are not specified' do
        before do
          Backup::Database::MongoDB.any_instance.expects(:utility).
              with(:mongodump).returns('/real/mongodump')
          Backup::Database::MongoDB.any_instance.expects(:utility).
              with(:mongo).returns('/real/mongo')
        end

        it 'should provide default values' do
          db = Backup::Database::MongoDB.new(model)

          db.name.should      be_nil
          db.username.should  be_nil
          db.password.should  be_nil
          db.host.should      be_nil
          db.port.should      be_nil

          db.ipv6.should                be_false
          db.only_collections.should    == []
          db.additional_options.should  == []
          db.mongodump_utility.should   == '/real/mongodump'
          db.mongo_utility.should       == '/real/mongo'
          db.lock.should                be_false
        end
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Database::MongoDB.defaults do |db|
          db.name       = 'db_name'
          db.username   = 'db_username'
          db.password   = 'db_password'
          db.host       = 'db_host'
          db.port       = 789

          db.ipv6               = 'default_ipv6'
          db.only_collections   = ['collection']
          db.additional_options = ['--opt']
          db.mongodump_utility  = '/default/path/to/mongodump'
          db.mongo_utility      = '/default/path/to/mongo'
          db.lock               = 'default_lock'
        end
      end

      after { Backup::Database::MongoDB.clear_defaults! }

      context 'when options are specified' do
        it 'should override the pre-configured defaults' do
          db.name.should      == 'mydatabase'
          db.username.should  == 'someuser'
          db.password.should  == 'secret'
          db.host.should      == 'localhost'
          db.port.should      == 123

          db.ipv6.should                == true
          db.only_collections.should    == ['users', 'pirates']
          db.additional_options.should  == ['--query', '--foo']
          db.mongodump_utility.should   == '/path/to/mongodump'
          db.mongo_utility.should       == '/path/to/mongo'
          db.lock.should                == true
        end
      end

      context 'when options are not specified' do
        it 'should use the pre-configured defaults' do
          db = Backup::Database::MongoDB.new(model)

          db.name.should      == 'db_name'
          db.username.should  == 'db_username'
          db.password.should  == 'db_password'
          db.host.should      == 'db_host'
          db.port.should      == 789

          db.ipv6.should                == 'default_ipv6'
          db.only_collections.should    == ['collection']
          db.additional_options.should  == ['--opt']
          db.mongodump_utility.should   == '/default/path/to/mongodump'
          db.mongo_utility.should       == '/default/path/to/mongo'
          db.lock.should                == 'default_lock'
        end
      end
    end # context 'when no pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#perform!' do
    let(:s) { sequence '' }

    before do
      # superclass actions
      db.expects(:prepare!).in_sequence(s)
      db.expects(:log!).in_sequence(s)
    end

    context 'when #lock is set to false' do
      before { db.lock = false }

      context 'when #only_collections has not been specified' do
        before { db.only_collections = [] }
        it 'should dump everything without locking' do
          db.expects(:lock_database).never
          db.expects(:unlock_database).never
          db.expects(:specific_collection_dump!).never

          db.expects(:dump!).in_sequence(s)
          db.expects(:package!).in_sequence(s)
          db.perform!
        end
      end

      context 'when #only_collections has been specified' do
        it 'should dump specific collections without locking' do
          db.expects(:lock_database).never
          db.expects(:unlock_database).never
          db.expects(:dump!).never

          db.expects(:specific_collection_dump!).in_sequence(s)
          db.expects(:package!).in_sequence(s)
          db.perform!
        end
      end

    end # context 'when #lock is set to false'

    context 'when #lock is set to true' do

      context 'when #only_collections has not been specified' do
        before { db.only_collections = [] }
        it 'should dump everything while locking the database' do
          db.expects(:specific_collection_dump!).never

          db.expects(:lock_database).in_sequence(s)
          db.expects(:dump!).in_sequence(s)
          db.expects(:unlock_database).in_sequence(s)
          db.expects(:package!).in_sequence(s)
          db.perform!
        end
      end

      context 'when #only_collections has been specified' do
        it 'should dump specific collections without locking' do
          db.expects(:lock_database).never
          db.expects(:unlock_database).never
          db.expects(:dump!).never

          db.expects(:lock_database).in_sequence(s)
          db.expects(:specific_collection_dump!).in_sequence(s)
          db.expects(:unlock_database).in_sequence(s)
          db.expects(:package!).in_sequence(s)
          db.perform!
        end
      end

    end # context 'when #lock is set to true'

    context 'when errors occur' do
      it 'should re-raise error and skip package!' do
        db.lock = false

        db.expects(:specific_collection_dump!).in_sequence(s).
            raises('Test Error Message')
        db.expects(:package!).never

        expect do
          db.perform!
        end.to raise_error(
          Backup::Errors::Database::MongoDBError,
          "Database::MongoDBError: Database Dump Failed!\n" +
          "  Reason: RuntimeError\n" +
          "  Test Error Message"
        )
      end

      it 'should ensure database is unlocked' do
        db.expects(:lock_database).in_sequence(s)
        db.expects(:specific_collection_dump!).in_sequence(s).
            raises('Test Error Message')
        db.expects(:unlock_database).in_sequence(s)
        db.expects(:package!).never

        expect do
          db.perform!
        end.to raise_error(
          Backup::Errors::Database::MongoDBError,
          "Database::MongoDBError: Database Dump Failed!\n" +
          "  Reason: RuntimeError\n" +
          "  Test Error Message"
        )
      end
    end

  end # describe '#perform!'

  describe '#dump!' do
    it 'should run the mongodb dump command' do
      db.expects(:mongodump).returns(:dump_command)
      db.expects(:run).with(:dump_command)
      db.send(:dump!)
    end
  end

  describe '#specific_collection_dump!' do
    it 'should run the mongodb dump command for each collection' do
      db.expects(:mongodump).twice.returns('dump_command')
      db.expects(:run).with("dump_command --collection='users'")
      db.expects(:run).with("dump_command --collection='pirates'")
      db.send(:specific_collection_dump!)
    end
  end

  describe '#mongodump' do
    before do
      db.instance_variable_set(:@dump_path, '/path/to/dump/folder')
    end

    it 'should return the mongodb dump command string' do
      db.send(:mongodump).should == "/path/to/mongodump " +
        "--db='mydatabase' --username='someuser' --password='secret' " +
        "--host='localhost' --port='123' --ipv6 " +
        "--query --foo --out='/path/to/dump/folder'"
    end
  end

  describe '#package!' do
    let(:compressor) { mock }
    let(:pipeline) { mock }
    let(:timestamp) { Time.now.to_i.to_s[-5, 5] }
    let(:s) { sequence '' }

    context 'when a compressor is configured' do
      before do
        Timecop.freeze(Time.now)
        db.instance_variable_set(:@dump_path, '/path/to/dump/folder')
        db.expects(:utility).with(:tar).returns('tar')
        model.expects(:compressor).twice.returns(compressor)
        compressor.expects(:compress_with).yields('compressor_command', '.gz')
        Backup::Pipeline.expects(:new).returns(pipeline)
      end

      context 'when pipeline command succeeds' do
        it 'should package the dump directory, then remove it' do

          Backup::Logger.expects(:message).in_sequence(s).with(
            "Database::MongoDB started compressing and packaging:\n" +
            "  '/path/to/dump/folder'"
          )

          pipeline.expects(:<<).in_sequence(s).with(
            "tar -cf - -C '/path/to/dump' 'folder'"
          )
          pipeline.expects(:<<).in_sequence(s).with('compressor_command')
          pipeline.expects(:<<).in_sequence(s).with(
            "cat > /path/to/dump/folder-#{ timestamp }.tar.gz"
          )

          pipeline.expects(:run).in_sequence(s)
          pipeline.expects(:success?).in_sequence(s).returns(true)
          Backup::Logger.expects(:message).in_sequence(s).with(
            "Database::MongoDB completed compressing and packaging:\n" +
            "  '/path/to/dump/folder-#{ timestamp }.tar.gz'"
          )
          FileUtils.expects(:rm_rf).in_sequence(s).with('/path/to/dump/folder')

          db.send(:package!)
        end
      end #context 'when pipeline command succeeds'

      context 'when pipeline command fails' do
        before do
          pipeline.stubs(:<<)
          pipeline.expects(:run)
          pipeline.expects(:success?).returns(false)
          pipeline.expects(:error_messages).returns('pipeline_errors')
        end

        it 'should raise an error' do
          Backup::Logger.expects(:message).with(
            "Database::MongoDB started compressing and packaging:\n" +
            "  '/path/to/dump/folder'"
          )

          expect do
            db.send(:package!)
          end.to raise_error(
            Backup::Errors::Database::PipelineError,
            "Database::PipelineError: Database::MongoDB " +
            "Failed to create compressed dump package:\n" +
            "  '/path/to/dump/folder-#{ timestamp }.tar.gz'\n" +
            "  pipeline_errors"
          )
        end
      end # context 'when pipeline command fails'
    end

    context 'when a compressor is not configured' do
      before do
        model.expects(:compressor).returns(nil)
      end

      it 'should return nil' do
        Backup::Pipeline.expects(:new).never
        db.send(:package!).should be_nil
      end
    end
  end # describe '#package!'

  describe '#database' do
    context 'when a database name is given' do
      it 'should return the command string for the database' do
        db.send(:database).should == "--db='mydatabase'"
      end
    end

    context 'when no database name is given' do
      it 'should return nil' do
        db.name = nil
        db.send(:database).should be_nil
      end
    end
  end

  describe '#credential_options' do
    it 'should return the command string for the user credentials' do
      db.send(:credential_options).should ==
          "--username='someuser' --password='secret'"
    end
  end

  describe '#connectivity_options' do
    it 'should return the command string for the connectivity options' do
      db.send(:connectivity_options).should == "--host='localhost' --port='123'"
    end
  end

  describe '#ipv6_option' do
    context 'when #ipv6 is set true' do
      it 'should return the command string for the ipv6 option' do
        db.send(:ipv6_option).should == '--ipv6'
      end
    end

    context 'when #ipv6 is set false' do
      it 'should return and empty string' do
        db.ipv6 = false
        db.send(:ipv6_option).should == ''
      end
    end
  end

  describe '#user_options' do
    context 'when #additional_options are set' do
      it 'should return the command string for the options' do
        db.send(:user_options).should == '--query --foo'
      end
    end

    context 'when #additional_options are not set' do
      it 'should return an empty string' do
        db.additional_options = []
        db.send(:user_options).should == ''
      end
    end
  end

  describe '#dump_directory' do
    it 'should return the command string for the dump path' do
      db.instance_variable_set(:@dump_path, '/path/to/dump/folder')
      db.send(:dump_directory).should == "--out='/path/to/dump/folder'"
    end
  end

  describe '#lock_database' do
    it 'should return the command to lock the database' do
      db.stubs(:mongo_uri).returns(:mongo_uri_output)
      db.expects(:run).with(
        " echo 'use admin\n" +
        ' db.runCommand({"fsync" : 1, "lock" : 1})\' | /path/to/mongo mongo_uri_output' +
        "\n"
      )
      db.send(:lock_database)
    end
  end

  describe '#unlock_database' do
    it 'should return the command to unlock the database' do
      db.stubs(:mongo_uri).returns(:mongo_uri_output)
      db.expects(:run).with(
        " echo 'use admin\n" +
        ' db.$cmd.sys.unlock.findOne()\' | /path/to/mongo mongo_uri_output' +
        "\n"
      )
      db.send(:unlock_database)
    end
  end

  describe '#mongo_uri' do
    before do
      db.stubs(:credential_options).returns(:credential_options_output)
      db.stubs(:ipv6_option).returns(:ipv6_option_output)
    end

    context 'when a database name is given' do
      it 'should return the URI specifying the database' do
        db.send(:mongo_uri).should ==
          "localhost:123/mydatabase credential_options_output ipv6_option_output"
      end
    end

    context 'when no database name is given' do
      it 'should return the URI without specifying the database' do
        db.name = nil
        db.send(:mongo_uri).should ==
          "localhost:123 credential_options_output ipv6_option_output"
      end
    end
  end

  describe 'deprecations' do
    describe '#utility_path' do
      before do
        Backup::Database::MongoDB.any_instance.stubs(:utility)
        Backup::Logger.expects(:warn).with {|err|
          err.should be_an_instance_of Backup::Errors::ConfigurationError
          err.message.should match(
            /Use MongoDB#mongodump_utility instead/
          )
        }
      end
      after do
        Backup::Database::MongoDB.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          mongodb = Backup::Database::MongoDB.new(model) do |db|
            db.utility_path = 'foo'
          end
          mongodb.mongodump_utility.should == 'foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          mongodb = Backup::Database::MongoDB.defaults do |db|
            db.utility_path = 'foo'
          end
          mongodb = Backup::Database::MongoDB.new(model)
          mongodb.mongodump_utility.should == 'foo'
        end
      end
    end # describe '#utility_path'
  end
end
