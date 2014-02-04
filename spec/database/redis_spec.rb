# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Database::Redis do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:required_config) {
    Proc.new do |redis|
      redis.rdb_path = 'rdb_path_required_for_copy_mode'
    end
  }
  let(:db) { Database::Redis.new(model, &required_config) }
  let(:s) { sequence '' }

  before do
    Database::Redis.any_instance.stubs(:utility).
        with('redis-cli').returns('redis-cli')
    Database::Redis.any_instance.stubs(:utility).
        with(:cat).returns('cat')
  end

  it_behaves_like 'a class that includes Config::Helpers' do
    let(:default_overrides) { { 'mode' => :sync } }
    let(:new_overrides) { { 'mode' => :copy } }
  end
  it_behaves_like 'a subclass of Database::Base'

  describe '#initialize' do

    it 'provides default values' do
      expect( db.database_id        ).to be_nil
      expect( db.mode               ).to eq :copy
      expect( db.rdb_path           ).to eq 'rdb_path_required_for_copy_mode'
      expect( db.invoke_save        ).to be_nil
      expect( db.host               ).to be_nil
      expect( db.port               ).to be_nil
      expect( db.socket             ).to be_nil
      expect( db.password           ).to be_nil
      expect( db.additional_options ).to be_nil
    end

    it 'configures the database' do
      db = Database::Redis.new(model, :my_id) do |redis|
        redis.mode               = :copy
        redis.rdb_path           = 'my_path'
        redis.invoke_save        = true
        redis.host               = 'my_host'
        redis.port               = 'my_port'
        redis.socket             = 'my_socket'
        redis.password           = 'my_password'
        redis.additional_options = 'my_additional_options'
      end

      expect( db.database_id        ).to eq 'my_id'
      expect( db.mode               ).to eq :copy
      expect( db.rdb_path           ).to eq 'my_path'
      expect( db.invoke_save        ).to be true
      expect( db.host               ).to eq 'my_host'
      expect( db.port               ).to eq 'my_port'
      expect( db.socket             ).to eq 'my_socket'
      expect( db.password           ).to eq 'my_password'
      expect( db.additional_options ).to eq 'my_additional_options'
    end

    it 'raises an error if mode is invalid' do
      expect do
        Database::Redis.new(model) do |redis|
          redis.mode = 'sync' # symbol required
        end
      end.to raise_error(Database::Redis::Error) {|err|
        expect( err.message ).to match(/not a valid mode/)
      }
    end

    it 'raises an error if rdb_path is not set for :copy mode' do
      expect do
        Database::Redis.new(model) do |redis|
          redis.rdb_path = nil
        end
      end.to raise_error(Database::Redis::Error) {|err|
        expect( err.message ).to match(/`rdb_path` must be set/)
      }
    end
  end # describe '#initialize'

  describe '#perform!' do
    before do
      db.expects(:log!).in_sequence(s).with(:started)
      db.expects(:prepare!).in_sequence(s)
    end

    context 'when mode is :sync' do
      before do
        db.mode = :sync
      end

      it 'uses sync!' do
        Logger.expects(:configure).in_sequence(s)
        db.expects(:sync!).in_sequence(s)
        db.expects(:log!).in_sequence(s).with(:finished)
        db.perform!
      end
    end

    context 'when mode is :copy' do
      before do
        db.mode = :copy
      end

      context 'when :invoke_save is false' do
        it 'calls copy! without save!' do
          Logger.expects(:configure).never
          db.expects(:save!).never
          db.expects(:copy!).in_sequence(s)
          db.expects(:log!).in_sequence(s).with(:finished)
          db.perform!
        end
      end

      context 'when :invoke_save is true' do
        before do
          db.invoke_save = true
        end

        it 'calls save! before copy!' do
          Logger.expects(:configure).never
          db.expects(:save!).in_sequence(s)
          db.expects(:copy!).in_sequence(s)
          db.expects(:log!).in_sequence(s).with(:finished)
          db.perform!
        end
      end
    end
  end # describe '#perform!'

  describe '#sync!' do
    let(:pipeline) { mock }
    let(:compressor) { mock }

    before do
      db.stubs(:redis_cli_cmd).returns('redis_cli_cmd')
      db.stubs(:dump_path).returns('/tmp/trigger/databases')
    end

    context 'without a compressor' do
      it 'packages the dump without compression' do
        Pipeline.expects(:new).in_sequence(s).returns(pipeline)

        pipeline.expects(:<<).in_sequence(s).with('redis_cli_cmd --rdb -')

        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/tmp/trigger/databases/Redis.rdb'"
        )

        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        db.send(:sync!)
      end
    end # context 'without a compressor'

    context 'with a compressor' do
      before do
        model.stubs(:compressor).returns(compressor)
        compressor.stubs(:compress_with).yields('cmp_cmd', '.cmp_ext')
      end

      it 'packages the dump with compression' do
        Pipeline.expects(:new).in_sequence(s).returns(pipeline)

        pipeline.expects(:<<).in_sequence(s).with('redis_cli_cmd --rdb -')

        pipeline.expects(:<<).in_sequence(s).with('cmp_cmd')

        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/tmp/trigger/databases/Redis.rdb.cmp_ext'"
        )

        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        db.send(:sync!)
      end
    end # context 'without a compressor'

    context 'when the pipeline fails' do
      before do
        Pipeline.any_instance.stubs(:success?).returns(false)
        Pipeline.any_instance.stubs(:error_messages).returns('error messages')
      end

      it 'raises an error' do
        expect do
          db.send(:sync!)
        end.to raise_error(Database::Redis::Error) {|err|
          expect( err.message ).to eq(
            "Database::Redis::Error: Dump Failed!\n  error messages"
          )
        }
      end
    end # context 'when the pipeline fails'

  end # describe '#sync!'

  describe '#save!' do
    before do
      db.stubs(:redis_cli_cmd).returns('redis_cli_cmd')
    end

    # the redis docs say this returns "+OK\n", although it appears
    # to only return "OK\n". Utilities#run strips the STDOUT returned,
    # so a successful response should =~ /OK$/

    specify 'when response is OK' do
      db.expects(:run).with('redis_cli_cmd SAVE').returns('+OK')
      db.send(:save!)
    end

    specify 'when response is not OK' do
      db.expects(:run).with('redis_cli_cmd SAVE').returns('No OK Returned')
      expect do
        db.send(:save!)
      end.to raise_error(Database::Redis::Error) {|err|
        expect( err.message ).to match(/Failed to invoke the `SAVE` command/)
        expect( err.message ).to match(/Response was: No OK Returned/)
      }
    end

    specify 'retries if save already in progress' do
      db.expects(:run).with('redis_cli_cmd SAVE').times(5).
          returns('Background save already in progress')
      db.expects(:sleep).with(5).times(4)
      expect do
        db.send(:save!)
      end.to raise_error(Database::Redis::Error) {|err|
        expect( err.message ).to match(/Failed to invoke the `SAVE` command/)
        expect( err.message ).to match(
          /Response was: Background save already in progress/
        )
      }
    end
  end # describe '#save!'

  describe '#copy!' do
    before do
      db.stubs(:dump_path).returns('/tmp/trigger/databases')
      db.rdb_path = '/var/lib/redis/dump.rdb'
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

  describe '#redis_cli_cmd' do
    let(:option_methods) {%w[
      password_option connectivity_options user_options
    ]}

    it 'returns full redis-cli command built from all options' do
      option_methods.each {|name| db.stubs(name).returns(name) }
      expect( db.send(:redis_cli_cmd) ).to eq(
        "redis-cli #{ option_methods.join(' ') }"
      )
    end

    it 'handles nil values from option methods' do
      option_methods.each {|name| db.stubs(name).returns(nil) }
      expect( db.send(:redis_cli_cmd) ).to eq(
        "redis-cli #{ (' ' * (option_methods.count - 1)) }"
      )
    end
  end # describe '#redis_cli_cmd'

  describe 'redis_cli_cmd option methods' do

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

  end # describe 'redis_cli_cmd option methods'

end
end
