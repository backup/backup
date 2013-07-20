# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Database::MongoDB do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:db) { Database::MongoDB.new(model) }
  let(:s) { sequence '' }

  before do
    Database::MongoDB.any_instance.stubs(:utility).
        with(:mongodump).returns('mongodump')
    Database::MongoDB.any_instance.stubs(:utility).
        with(:mongo).returns('mongo')
    Database::MongoDB.any_instance.stubs(:utility).
        with(:cat).returns('cat')
    Database::MongoDB.any_instance.stubs(:utility).
        with(:tar).returns('tar')
  end

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Database::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( db.database_id        ).to be_nil
      expect( db.name               ).to be_nil
      expect( db.username           ).to be_nil
      expect( db.password           ).to be_nil
      expect( db.host               ).to be_nil
      expect( db.port               ).to be_nil
      expect( db.ipv6               ).to be_nil
      expect( db.only_collections   ).to be_nil
      expect( db.additional_options ).to be_nil
      expect( db.lock               ).to be_nil
      expect( db.oplog              ).to be_nil
    end

    it 'configures the database' do
      db = Database::MongoDB.new(model, :my_id) do |mongodb|
        mongodb.name               = 'my_name'
        mongodb.username           = 'my_username'
        mongodb.password           = 'my_password'
        mongodb.host               = 'my_host'
        mongodb.port               = 'my_port'
        mongodb.ipv6               = 'my_ipv6'
        mongodb.only_collections   = 'my_only_collections'
        mongodb.additional_options = 'my_additional_options'
        mongodb.lock               = 'my_lock'
        mongodb.oplog              = 'my_oplog'
      end

      expect( db.database_id        ).to eq 'my_id'
      expect( db.name               ).to eq 'my_name'
      expect( db.username           ).to eq 'my_username'
      expect( db.password           ).to eq 'my_password'
      expect( db.host               ).to eq 'my_host'
      expect( db.port               ).to eq 'my_port'
      expect( db.ipv6               ).to eq 'my_ipv6'
      expect( db.only_collections   ).to eq 'my_only_collections'
      expect( db.additional_options ).to eq 'my_additional_options'
      expect( db.lock               ).to eq 'my_lock'
      expect( db.oplog              ).to eq 'my_oplog'
    end
  end # describe '#initialize'

  describe '#perform!' do
    before do
      db.expects(:log!).in_sequence(s).with(:started)
      db.expects(:prepare!).in_sequence(s)
    end

    context 'with #lock set to false' do
      it 'does not lock the database' do
        db.expects(:lock_database).never
        db.expects(:unlock_database).never

        db.expects(:dump!).in_sequence(s)
        db.expects(:package!).in_sequence(s)

        db.perform!
      end
    end

    context 'with #lock set to true' do
      before { db.lock = true }

      it 'locks the database' do
        db.expects(:lock_database).in_sequence(s)
        db.expects(:dump!).in_sequence(s)
        db.expects(:package!).in_sequence(s)
        db.expects(:unlock_database).in_sequence(s)

        db.perform!
      end

      it 'ensures the database is unlocked' do
        db.expects(:lock_database).in_sequence(s)
        db.expects(:dump!).in_sequence(s)
        db.expects(:package!).in_sequence(s).raises('an error')
        db.expects(:unlock_database).in_sequence(s)

        expect do
          db.perform!
        end.to raise_error 'an error'
      end
    end

  end # describe '#perform!'

  describe '#dump!' do
    before do
      db.stubs(:mongodump).returns('mongodump_command')
      db.stubs(:dump_path).returns('/tmp/trigger/databases')

      FileUtils.expects(:mkdir_p).in_sequence(s).
          with('/tmp/trigger/databases/MongoDB')
    end

    context 'when #only_collections are not specified' do
      it 'runs mongodump once' do
        db.expects(:run).in_sequence(s).with('mongodump_command')
        db.send(:dump!)
      end
    end

    context 'when #only_collections are specified' do
      it 'runs mongodump for each collection' do
        db.only_collections = ['collection_a', 'collection_b']

        db.expects(:run).in_sequence(s).with(
          "mongodump_command --collection='collection_a'"
        )
        db.expects(:run).in_sequence(s).with(
          "mongodump_command --collection='collection_b'"
        )

        db.send(:dump!)
      end

      it 'allows only_collections to be a single string' do
        db.only_collections = 'collection_a'

        db.expects(:run).in_sequence(s).with(
          "mongodump_command --collection='collection_a'"
        )

        db.send(:dump!)
      end
    end
  end # describe '#dump!'

  describe '#package!' do
    let(:pipeline) { mock }
    let(:compressor) { mock }

    before do
      db.stubs(:dump_path).returns('/tmp/trigger/databases')
    end

    context 'without a compressor' do
      it 'packages the dump without compression' do
        Pipeline.expects(:new).in_sequence(s).returns(pipeline)
        pipeline.expects(:<<).in_sequence(s).with(
          "tar -cf - -C '/tmp/trigger/databases' 'MongoDB'"
        )
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/tmp/trigger/databases/MongoDB.tar'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)
        FileUtils.expects(:rm_rf).in_sequence(s).with(
          '/tmp/trigger/databases/MongoDB'
        )
        db.expects(:log!).in_sequence(s).with(:finished)

        db.send(:package!)
      end
    end # context 'without a compressor'

    context 'with a compressor' do
      before do
        model.stubs(:compressor).returns(compressor)
        compressor.stubs(:compress_with).yields('cmp_cmd', '.cmp_ext')
      end

      it 'packages the dump with compression' do
        Pipeline.expects(:new).in_sequence(s).returns(pipeline)
        pipeline.expects(:<<).in_sequence(s).with(
          "tar -cf - -C '/tmp/trigger/databases' 'MongoDB'"
        )
        pipeline.expects(:<<).in_sequence(s).with('cmp_cmd')
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/tmp/trigger/databases/MongoDB.tar.cmp_ext'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)
        FileUtils.expects(:rm_rf).in_sequence(s).with(
          '/tmp/trigger/databases/MongoDB'
        )
        db.expects(:log!).in_sequence(s).with(:finished)

        db.send(:package!)
      end
    end # context 'with a compressor'

    context 'when the pipeline fails' do
      before do
        Pipeline.any_instance.stubs(:success?).returns(false)
        Pipeline.any_instance.stubs(:error_messages).returns('error messages')
      end

      it 'raises an error and does not remove the packaging path' do
        FileUtils.expects(:rm_rf).never
        db.expects(:log!).never

        expect do
          db.send(:package!)
        end.to raise_error(Database::MongoDB::Error) {|err|
          expect( err.message ).to eq(
            "Database::MongoDB::Error: Dump Failed!\n  error messages"
          )
        }
      end
    end # context 'when the pipeline fails'
  end # describe '#package!'

  describe '#mongodump' do
    let(:option_methods) {%w[
      name_option credential_options connectivity_options
      ipv6_option oplog_option user_options dump_packaging_path
    ]}

    it 'returns full mongodump command built from all options' do
      option_methods.each {|name| db.stubs(name).returns(name) }
      expect( db.send(:mongodump) ).to eq(
        "mongodump name_option credential_options connectivity_options " +
        "ipv6_option oplog_option user_options --out='dump_packaging_path'"
      )
    end

    it 'handles nil values from option methods' do
      option_methods.each {|name| db.stubs(name).returns(nil) }
      expect( db.send(:mongodump) ).to eq "mongodump       --out=''"
    end
  end # describe '#mongodump'

  describe 'mongo and monogodump option methods' do

    describe '#name_option' do
      it 'returns database argument if #name is specified' do
        expect( db.send(:name_option) ).to be_nil

        db.name = 'my_database'
        expect( db.send(:name_option) ).to eq "--db='my_database'"
      end
    end # describe '#name_option'

    describe '#credential_options' do
      it 'returns credentials arguments based on #username and #password' do
        expect( db.send(:credential_options) ).to eq ''

        db.username = 'my_user'
        expect( db.send(:credential_options) ).to eq(
          "--username='my_user'"
        )

        db.password = 'my_password'
        expect( db.send(:credential_options) ).to eq(
          "--username='my_user' --password='my_password'"
        )

        db.username = nil
        expect( db.send(:credential_options) ).to eq(
          "--password='my_password'"
        )
      end
    end # describe '#credential_options'

    describe '#connectivity_options' do
      it 'returns connectivity arguments based on #host and #port' do
        expect( db.send(:connectivity_options) ).to eq ''

        db.host = 'my_host'
        expect( db.send(:connectivity_options) ).to eq(
          "--host='my_host'"
        )

        db.port = 'my_port'
        expect( db.send(:connectivity_options) ).to eq(
          "--host='my_host' --port='my_port'"
        )

        db.host = nil
        expect( db.send(:connectivity_options) ).to eq(
          "--port='my_port'"
        )
      end
    end # describe '#connectivity_options'

    describe '#ipv6_option' do
      it 'returns the ipv6 argument if #ipv6 is true' do
        expect( db.send(:ipv6_option) ).to be_nil

        db.ipv6 = true
        expect( db.send(:ipv6_option) ).to eq '--ipv6'
      end
    end # describe '#ipv6_option'

    describe '#oplog_option' do
      it 'returns the oplog argument if #oplog is true' do
        expect( db.send(:oplog_option) ).to be_nil

        db.oplog = true
        expect( db.send(:oplog_option) ).to eq '--oplog'
      end
    end # describe '#oplog_option'

    describe '#user_options' do
      it 'returns arguments for any #additional_options specified' do
        expect( db.send(:user_options) ).to eq ''

        db.additional_options = ['--opt1', '--opt2']
        expect( db.send(:user_options) ).to eq '--opt1 --opt2'

        db.additional_options = '--opta --optb'
        expect( db.send(:user_options) ).to eq '--opta --optb'
      end
    end # describe '#user_options'

  end # describe 'mongo and monogodump option methods'

  describe '#lock_database' do
    it 'runs command to disable profiling and lock the database' do
      db = Database::MongoDB.new(model)
      db.stubs(:mongo_shell).returns('mongo_shell')

      db.expects(:run).with(
        "echo 'use admin\n" +
        "db.setProfilingLevel(0)\n" +
        "db.fsyncLock()' | mongo_shell\n"
      )
      db.send(:lock_database)
    end
  end # describe '#lock_database'

  describe '#unlock_database' do
    it 'runs command to unlock the database' do
      db = Database::MongoDB.new(model)
      db.stubs(:mongo_shell).returns('mongo_shell')

      db.expects(:run).with(
        "echo 'use admin\n" +
        "db.fsyncUnlock()' | mongo_shell\n"
      )
      db.send(:unlock_database)
    end
  end # describe '#unlock_database'

  describe '#mongo_shell' do
    specify 'with all options' do
      db.host = 'my_host'
      db.port = 'my_port'
      db.username = 'my_user'
      db.password = 'my_pwd'
      db.ipv6 = true
      db.name = 'my_db'

      expect( db.send(:mongo_shell) ).to eq(
        "mongo --host='my_host' --port='my_port' --username='my_user' " +
        "--password='my_pwd' --ipv6 'my_db'"
      )
    end

    specify 'with no options' do
      expect( db.send(:mongo_shell) ).to eq 'mongo'
    end
  end # describe '#mongo_shell'

  describe 'deprecations' do

    describe '#utility_path' do
      before do
        # to satisfy Utilities.configure
        File.stubs(:executable?).with('/foo').returns(true)
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use Backup::Utilities\.configure instead/
          )
        }
      end
      after do
        Database::MongoDB.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::MongoDB.new(model) do |db|
            db.utility_path = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['mongodump'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::MongoDB.defaults do |db|
            db.utility_path = '/foo'
          end
          Database::MongoDB.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['mongodump'] ).to eq '/foo'
        end
      end
    end # describe '#utility_path'

    describe '#mongodump_utility' do
      before do
        # to satisfy Utilities.configure
        File.stubs(:executable?).with('/foo').returns(true)
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use Backup::Utilities\.configure instead/
          )
        }
      end
      after do
        Database::MongoDB.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::MongoDB.new(model) do |db|
            db.mongodump_utility = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['mongodump'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::MongoDB.defaults do |db|
            db.mongodump_utility = '/foo'
          end
          Database::MongoDB.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['mongodump'] ).to eq '/foo'
        end
      end
    end # describe '#mongodump_utility'

    describe '#mongo_utility' do
      before do
        # to satisfy Utilities.configure
        File.stubs(:executable?).with('/foo').returns(true)
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use Backup::Utilities\.configure instead/
          )
        }
      end
      after do
        Database::MongoDB.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::MongoDB.new(model) do |db|
            db.mongo_utility = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['mongo'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::MongoDB.defaults do |db|
            db.mongo_utility = '/foo'
          end
          Database::MongoDB.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['mongo'] ).to eq '/foo'
        end
      end
    end # describe '#mongo_utility'

  end # describe 'deprecations'

end
end
