# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Database::Redis do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:db) { Database::Redis.new(model) }
  let(:s) { sequence '' }

  before do
    Database::Redis.any_instance.stubs(:utility).
        with('redis-cli').returns('redis-cli')
  end

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Database::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( db.database_id        ).to be_nil
      expect( db.name               ).to eq 'dump'
      expect( db.path               ).to be_nil
      expect( db.password           ).to be_nil
      expect( db.host               ).to be_nil
      expect( db.port               ).to be_nil
      expect( db.socket             ).to be_nil
      expect( db.invoke_save        ).to be_nil
      expect( db.additional_options ).to be_nil
    end

    it 'configures the database' do
      db = Database::Redis.new(model, :my_id) do |redis|
        redis.name               = 'my_name'
        redis.path               = 'my_path'
        redis.password           = 'my_password'
        redis.host               = 'my_host'
        redis.port               = 'my_port'
        redis.socket             = 'my_socket'
        redis.invoke_save        = 'my_invoke_save'
        redis.additional_options = 'my_additional_options'
      end

      expect( db.database_id        ).to eq 'my_id'
      expect( db.name               ).to eq 'my_name'
      expect( db.path               ).to eq 'my_path'
      expect( db.password           ).to eq 'my_password'
      expect( db.host               ).to eq 'my_host'
      expect( db.port               ).to eq 'my_port'
      expect( db.socket             ).to eq 'my_socket'
      expect( db.invoke_save        ).to eq 'my_invoke_save'
      expect( db.additional_options ).to eq 'my_additional_options'
    end
  end # describe '#initialize'

  describe '#perform!' do
    before do
      db.expects(:log!).in_sequence(s).with(:started)
      db.expects(:prepare!).in_sequence(s)
    end

    specify 'when #invoke_save is true' do
      db.invoke_save = true

      db.expects(:invoke_save!).in_sequence(s)
      db.expects(:copy!).in_sequence(s)
      db.expects(:log!).in_sequence(s).with(:finished)

      db.perform!
    end

    specify 'when #invoke_save is false' do
      db.expects(:invoke_save!).never
      db.expects(:copy!).in_sequence(s)
      db.expects(:log!).in_sequence(s).with(:finished)

      db.perform!
    end
  end # describe '#perform!'

  describe '#invoke_save!' do
    before do
      db.stubs(:redis_save_cmd).returns('redis_save_cmd')
    end

    # the redis docs say this returns "+OK\n", although it appears
    # to only return "OK\n". Utilities#run strips the STDOUT returned,
    # so a successful response should =~ /OK$/

    specify 'when response is OK' do
      db.expects(:run).with('redis_save_cmd').returns('+OK')
      db.send(:invoke_save!)
    end

    specify 'when response is not OK' do
      db.expects(:run).with('redis_save_cmd').returns('No OK Returned')
      expect do
        db.send(:invoke_save!)
      end.to raise_error(Database::Redis::Error) {|err|
        expect( err.message ).to match(/Command was: redis_save_cmd/)
        expect( err.message ).to match(/Response was: No OK Returned/)
      }
    end

    specify 'retries if save already in progress' do
      db.expects(:run).with('redis_save_cmd').times(5).
          returns('Background save already in progress')
      db.expects(:sleep).with(5).times(4)
      expect do
        db.send(:invoke_save!)
      end.to raise_error(Database::Redis::Error) {|err|
        expect( err.message ).to match(/Command was: redis_save_cmd/)
        expect( err.message ).to match(
          /Response was: Background save already in progress/
        )
      }
    end
  end # describe '#invoke_save!'

  describe '#copy!' do
    before do
      db.stubs(:dump_path).returns('/tmp/trigger/databases')
      db.path = '/var/lib/redis'
    end

    context 'when the redis dump file exists' do
      before do
        File.expects(:exist?).in_sequence(s).with(
          '/var/lib/redis/dump.rdb'
        ).returns(true)
      end

      context 'when a compressor is configured' do
        let(:compressor) { mock }

        before do
          model.stubs(:compressor).returns(compressor)
          compressor.stubs(:compress_with).yields('cmp_cmd', '.cmp_ext')
        end

        it 'should copy the redis dump file with compression' do
          db.expects(:run).in_sequence(s).with(
            "cmp_cmd -c '/var/lib/redis/dump.rdb' > " +
            "'/tmp/trigger/databases/Redis.rdb.cmp_ext'"
          )
          FileUtils.expects(:cp).never

          db.send(:copy!)
        end
      end # context 'when a compressor is configured'

      context 'when no compressor is configured' do
        it 'should copy the redis dump file without compression' do
          FileUtils.expects(:cp).in_sequence(s).with(
            '/var/lib/redis/dump.rdb', '/tmp/trigger/databases/Redis.rdb'
          )
          db.expects(:run).never

          db.send(:copy!)
        end
      end # context 'when no compressor is configured'

    end # context 'when the redis dump file exists'

    context 'when the redis dump file does not exist' do
      it 'raises an error' do
        File.expects(:exist?).in_sequence(s).with(
          '/var/lib/redis/dump.rdb'
        ).returns(false)

        expect do
          db.send(:copy!)
        end.to raise_error(Database::Redis::Error)
      end
    end # context 'when the redis dump file does not exist'

  end # describe '#copy!'

  describe '#redis_save_cmd' do
    let(:option_methods) {%w[
      password_option connectivity_options user_options
    ]}

    it 'returns full redis-cli command built from all options' do
      option_methods.each {|name| db.stubs(name).returns(name) }
      expect( db.send(:redis_save_cmd) ).to eq(
        "redis-cli #{ option_methods.join(' ') } SAVE"
      )
    end

    it 'handles nil values from option methods' do
      option_methods.each {|name| db.stubs(name).returns(nil) }
      expect( db.send(:redis_save_cmd) ).to eq(
        "redis-cli #{ (' ' * (option_methods.count - 1)) } SAVE"
      )
    end
  end # describe '#redis_save_cmd'

  describe 'redis_save_cmd option methods' do

    describe '#password_option' do
      it 'returns argument if specified' do
        expect( db.send(:password_option) ).to be_nil

        db.password = 'my_password'
        expect( db.send(:password_option) ).to eq "-a 'my_password'"
      end
    end # describe '#password_option'

    describe '#connectivity_options' do
      it 'returns only the socket argument if #socket specified' do
        db.host = 'my_host'
        db.port = 'my_port'
        db.socket = 'my_socket'
        expect( db.send(:connectivity_options) ).to eq(
          "-s 'my_socket'"
        )
      end

      it 'returns host and port arguments if specified' do
        expect( db.send(:connectivity_options) ).to eq ''

        db.host = 'my_host'
        expect( db.send(:connectivity_options) ).to eq(
          "-h 'my_host'"
        )

        db.port = 'my_port'
        expect( db.send(:connectivity_options) ).to eq(
          "-h 'my_host' -p 'my_port'"
        )

        db.host = nil
        expect( db.send(:connectivity_options) ).to eq(
          "-p 'my_port'"
        )
      end
    end # describe '#connectivity_options'

    describe '#user_options' do
      it 'returns arguments for any #additional_options specified' do
        expect( db.send(:user_options) ).to eq ''

        db.additional_options = ['--opt1', '--opt2']
        expect( db.send(:user_options) ).to eq '--opt1 --opt2'

        db.additional_options = '--opta --optb'
        expect( db.send(:user_options) ).to eq '--opta --optb'
      end
    end # describe '#user_options'

  end # describe 'redis_save_cmd option methods'

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
        Database::Redis.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::Redis.new(model) do |db|
            db.utility_path = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['redis-cli'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::Redis.defaults do |db|
            db.utility_path = '/foo'
          end
          Database::Redis.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['redis-cli'] ).to eq '/foo'
        end
      end
    end # describe '#utility_path'

    describe '#redis_cli_utility' do
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
        Database::Redis.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::Redis.new(model) do |db|
            db.redis_cli_utility = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['redis-cli'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::Redis.defaults do |db|
            db.redis_cli_utility = '/foo'
          end
          Database::Redis.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['redis-cli'] ).to eq '/foo'
        end
      end
    end # describe '#redis_cli_utility'

  end # describe 'deprecations'
end
end
