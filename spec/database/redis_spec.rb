# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::Redis do
  let(:model) { Backup::Model.new('foo', 'foo') }
  let(:db) do
    Backup::Database::Redis.new(model) do |db|
      db.name         = 'mydatabase'
      db.path         = '/var/lib/redis/db/'
      db.password     = 'secret'
      db.host         = 'localhost'
      db.port         = '123'
      db.socket       = '/redis.sock'
      db.invoke_save  = true

      db.additional_options = ['--query', '--foo']
      db.redis_cli_utility  = '/path/to/redis-cli'
    end
  end

  describe '#initialize' do
    it 'should read the adapter details correctly' do
      db.name.should        == 'mydatabase'
      db.path.should        == '/var/lib/redis/db/'
      db.password.should    == 'secret'
      db.host.should        == 'localhost'
      db.port.should        == '123'
      db.socket.should      == '/redis.sock'
      db.invoke_save.should == true

      db.additional_options.should == ['--query', '--foo']
      db.redis_cli_utility.should  == '/path/to/redis-cli'
    end

    context 'when options are not set' do
      before do
        Backup::Database::Redis.any_instance.expects(:utility).
            with('redis-cli').returns('/real/redis-cli')
      end

      it 'should use default values' do
        db = Backup::Database::Redis.new(model)

        db.name.should        == 'dump'
        db.path.should        be_nil
        db.password.should    be_nil
        db.host.should        be_nil
        db.port.should        be_nil
        db.socket.should      be_nil
        db.invoke_save.should be_nil

        db.additional_options.should  == []
        db.redis_cli_utility.should   == '/real/redis-cli'
      end
    end

    context 'when configuration defaults have been set' do
      after { Backup::Configuration::Database::Redis.clear_defaults! }

      it 'should use configuration defaults' do
        Backup::Configuration::Database::Redis.defaults do |db|
          db.name         = 'db_name'
          db.path         = 'db_path'
          db.password     = 'db_password'
          db.host         = 'db_host'
          db.port         = 789
          db.socket       = '/foo.sock'
          db.invoke_save  = true

          db.additional_options = ['--add', '--opts']
          db.redis_cli_utility  = '/default/path/to/redis-cli'
        end

        db = Backup::Database::Redis.new(model)
        db.name.should        == 'db_name'
        db.path.should        == 'db_path'
        db.password.should    == 'db_password'
        db.host.should        == 'db_host'
        db.port.should        == 789
        db.socket.should      == '/foo.sock'
        db.invoke_save.should == true

        db.additional_options.should  == ['--add', '--opts']
        db.redis_cli_utility.should   == '/default/path/to/redis-cli'
      end
    end
  end # describe '#initialize'

  describe '#perform!' do
    let(:s) { sequence '' }
    before do
      # superclass actions
      db.expects(:prepare!).in_sequence(s)
      db.expects(:log!).in_sequence(s)
    end

    context 'when #invoke_save is true' do
      before { db.invoke_save = true }
      it 'should copy over after persisting (saving) the most recent updates' do
        db.expects(:invoke_save!).in_sequence(s)
        db.expects(:copy!).in_sequence(s)

        db.perform!
      end
    end

    context 'when #invoke_save is not true' do
      before { db.invoke_save = nil }
      it 'should copy over without persisting (saving) first' do
        db.expects(:invoke_save!).never
        db.expects(:copy!).in_sequence(s)

        db.perform!
      end
    end

  end # describe '#perform!'

  describe '#invoke_save!' do
    before do
      db.stubs(:credential_options).returns(:credential_options_output)
      db.stubs(:connectivity_options).returns(:connectivity_options_output)
      db.stubs(:user_options).returns(:user_options_output)
    end

    context 'when response is OK' do
      it 'should run the redis-cli command string' do
        db.expects(:run).with(
          '/path/to/redis-cli credential_options_output ' +
          'connectivity_options_output user_options_output SAVE'
        ).returns('result OK for command')

        expect do
          db.send(:invoke_save!)
        end.not_to raise_error
      end
    end

    context 'when response is not OK' do
      it 'should raise an error' do
        db.stubs(:run).returns('result not ok for command')
        db.stubs(:database).returns('database_filename')

        expect do
          db.send(:invoke_save!)
        end.to raise_error {|err|
          err.should be_an_instance_of Backup::Errors::Database::Redis::CommandError
          err.message.should match(/Could not invoke the Redis SAVE command/)
          err.message.should match(/The database_filename file/)
          err.message.should match(/Redis CLI response: result not ok/)
        }
      end
    end

  end # describe '#invoke_save!'

  describe '#copy!' do
    let(:src_path)    { '/var/lib/redis/db/mydatabase.rdb' }
    let(:dst_path)    { '/dump/path/mydatabase.rdb' }
    let(:compressor)  { mock }

    context 'when the database exists' do
      before do
        db.instance_variable_set(:@dump_path, '/dump/path')
        File.expects(:exist?).with(src_path).returns(true)
      end

      context 'when no compressor is configured' do
        it 'should copy the database' do
          db.expects(:run).never

          FileUtils.expects(:cp).with(src_path, dst_path)
          db.send(:copy!)
        end
      end

      context 'when a compressor is configured' do
        before do
          model.stubs(:compressor).returns(compressor)
          compressor.expects(:compress_with).yields('compressor_command', '.gz')
        end

        it 'should copy the database using the compressor' do
          FileUtils.expects(:cp).never

          db.expects(:run).with(
            "compressor_command -c #{ src_path } > #{ dst_path }.gz"
          )
          db.send(:copy!)
        end
      end
    end

    context 'when the database does not exist' do
      it 'should raise an error if the database dump file is not found' do
        File.expects(:exist?).returns(false)
        expect do
          db.send(:copy!)
        end.to raise_error do |err|
          err.should be_an_instance_of Backup::Errors::Database::Redis::NotFoundError
          err.message.should match(/Redis database dump not found/)
          err.message.should match(/File path was #{src_path}/)
        end
      end
    end
  end # describe '#copy!'

  describe '#database' do
    it 'should return the database name with the extension added' do
      db.send(:database).should == 'mydatabase.rdb'
    end
  end

  describe '#credential_options' do
    context 'when #password is set' do
      it 'should return the redis-cli syntax for the credential options' do
        db.send(:credential_options).should == "-a 'secret'"
      end
    end

    context 'when password is not set' do
      it 'should return an empty string' do
        db.password = nil
        db.send(:credential_options).should == ''
      end
    end
  end

  describe '#connectivity_options' do
    it 'should return the redis syntax for the connectivity options' do
      db.send(:connectivity_options).should ==
        "-h 'localhost' -p '123' -s '/redis.sock'"
    end

    context 'when only the #port is set' do
      it 'should return only the port' do
        db.host   = nil
        db.socket = nil
        db.send(:connectivity_options).should == "-p '123'"
      end
    end
  end

  describe '#user_options' do
    context 'when #additional_options are set' do
      it 'should return the options' do
        db.send(:user_options).should == '--query --foo'
      end
    end

    context 'when #additional_options is not set' do
      it 'should return an empty string' do
        db.additional_options = []
        db.send(:user_options).should == ''
      end
    end
  end

end
