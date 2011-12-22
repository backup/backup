# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::Redis do

  before do
    Backup::Database::Redis.any_instance.stubs(:load_defaults!)
  end

  let(:db) do
    Backup::Database::Redis.new do |db|
      db.name        = 'mydatabase'
      db.path        = '/var/lib/redis/db/'
      db.password    = 'secret'
      db.host        =  'localhost'
      db.port        = 123
      db.socket      = '/redis.sock'
      db.invoke_save = true

      db.additional_options = ['--query']
    end
  end

  describe '#new' do
    it 'should read the adapter details correctly' do
      db.name.should        == 'mydatabase'
      db.password.should    == 'secret'
      db.host.should        == 'localhost'
      db.port.should        == 123
      db.socket.should      == '/redis.sock'
      db.invoke_save.should == true

      db.additional_options.should == '--query'
    end

    it 'arrays should default to empty arrays when not specified' do
      db = Backup::Database::Redis.new do |db|
        db.name     = 'mydatabase'
        db.password = 'secret'
      end

      db.additional_options.should == ""
    end
  end

  describe '#credential_options' do
    it 'should return the redis-cli syntax for the credential options' do
      db.credential_options.should == "-a 'secret'"
    end
  end

  describe '#connectivity_options' do
    it 'should return the redis syntax for the connectivity options' do
      db.connectivity_options.should == "-h 'localhost' -p '123' -s '/redis.sock'"
    end

    it 'should return only the port' do
      db = Backup::Database::Redis.new do |db|
        db.host   = nil
        db.port   = 123
      end

      db.connectivity_options.should == "-p '123'"
    end
  end

  describe '#invoke_save!' do

    it 'should return the full redis-cli string' do
      db.expects(:utility).with('redis-cli').returns('redis-cli')
      db.expects(:run).with("redis-cli -a 'secret' -h 'localhost' " +
                            "-p '123' -s '/redis.sock' --query SAVE")
      db.stubs(:raise)
      db.invoke_save!
    end

    it 'should raise and error if response is not OK' do
      db.stubs(:utility)
      db.stubs(:run).returns('BAD')
      expect { db.invoke_save! }.to raise_error do |err|
        err.should be_an_instance_of Backup::Errors::Database::Redis::CommandError
        err.message.should match(/Could not invoke the Redis SAVE command/)
        err.message.should match(/The #{db.database} file/)
        err.message.should match(/Redis CLI response: BAD/)
      end
    end

  end # describe '#invoke_save!'

  describe '#copy!' do
    it do
      File.expects(:exist?).returns(true)
      db.stubs(:utility).returns('cp')
      db.expects(:run).with("cp '#{ File.join('/var/lib/redis/db/mydatabase.rdb') }' '#{ File.join(Backup::TMP_PATH, Backup::TRIGGER, 'Redis', 'mydatabase.rdb') }'")
      db.expects(:mkdir).with(File.join(Backup::TMP_PATH, "myapp", "Redis"))
      db.prepare!
      db.copy!
    end

    it 'should find the cp utility when utility_path is set' do
      File.expects(:exist?).returns(true)
      db.utility_path = '/usr/local/bin/redis-cli'
      db.expects(:run).with { |v| v =~ %r{^/bin/cp .+} }
      db.expects(:mkdir).with(File.join(Backup::TMP_PATH, "myapp", "Redis"))
      db.prepare!
      db.copy!
    end

    it 'should raise an error if the database dump file is not found' do
      File.expects(:exist?).returns(false)
      expect { db.copy! }.to raise_error do |err|
        err.should be_an_instance_of Backup::Errors::Database::Redis::NotFoundError
        err.message.should match(/Redis database dump not found/)
        err.message.should match(/File path was #{File.join(db.path, db.database)}/)
      end
    end
  end

  describe '#perform!' do
    before do
      File.stubs(:exist?).returns(true)
      db.stubs(:utility).returns('redis-cli')
      db.stubs(:mkdir)
      db.stubs(:run)
      db.stubs(:raise)
    end

    it 'should ensure the directory is available' do
      db.expects(:mkdir).with(File.join(Backup::TMP_PATH, "myapp", "Redis"))
      db.perform!
    end

    it 'should copy over without persisting (saving) first' do
      db.invoke_save = nil
      db.expects(:invoke_save!).never
      db.expects(:copy!)

      db.perform!
    end

    it 'should copy over after persisting (saving) the most recent updates' do
      db.invoke_save = true
      db.expects(:invoke_save!)
      db.expects(:copy!)

      db.perform!
    end

    it do
      Backup::Logger.expects(:message).
          with("Backup::Database::Redis started dumping and archiving 'mydatabase'.")

      db.perform!
    end
  end
end
