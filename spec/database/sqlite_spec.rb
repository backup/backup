# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::SQLite do
  let(:model) { Backup::Model.new('foo', 'foo') }
  let(:db) do
    Backup::Database::SQLite.new(model) do |db|
      
      db.name      = 'db1'
      db.path      = '/tmp'
      db.sqlitedump_utility  = '/path/to/sqlitedump'
    end
  end

  it 'should be a subclass of Database::Base' do
    Backup::Database::SQLite.superclass.
      should == Backup::Database::Base
  end

  describe '#initialize' do

    it 'should load pre-configured defaults through Base' do
      Backup::Database::SQLite.any_instance.expects(:load_defaults!)
      db
    end

    it 'should pass the model reference to Base' do
      db.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      context 'when options are specified' do
        it 'should use the given values' do
          db.name.should      == 'db1'
          db.path.should      == '/tmp'          
          db.sqlitedump_utility.should  == '/path/to/sqlitedump'
        end
      end

    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Database::SQLite.defaults do |db|
          db.name       = 'db_name'
          db.sqlitedump_utility  = '/default/path/to/sqlitedump'
        end
      end

      after { Backup::Database::SQLite.clear_defaults! }

      context 'when options are specified' do
        it 'should override the pre-configured defaults' do
          db.name.should      == 'db1'
          db.path.should      == '/tmp'
          db.sqlitedump_utility.should  == '/path/to/sqlitedump'
        end
      end

      context 'when options are not specified' do
        it 'should use the pre-configured defaults' do
          db = Backup::Database::SQLite.new(model)

          db.name.should      == 'db_name'
          
          db.sqlitedump_utility.should   == '/default/path/to/sqlitedump'
        end
      end
    end # context 'when no pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#perform!' do
    let(:s) { sequence '' }
    let(:pipeline) { mock }
    let(:compressor) { mock }

    before do
      # superclass actions
      db.expects(:prepare!).in_sequence(s)
      db.expects(:log!).in_sequence(s)
      db.instance_variable_set(:@dump_path, '/dump/path')
      db.stubs(:dump_filename).returns('dump_filename')
      db.stubs(:db_name).returns(Array.new(["db_a", "db_b"]))
    end

    context 'when no compressor is configured' do
      before do
        
      end

      it 'should run sqlitedump without compression' do
         
        db.db_name.each do |d|
          Backup::Pipeline.expects(:new).returns(pipeline)
          pipeline.expects(:<<).in_sequence(s).with("echo '.dump' | /path/to/sqlitedump /tmp/#{d}")
          model.expects(:compressor).returns(nil)
          pipeline.expects(:<<).in_sequence(s).with("cat > '/dump/path/#{d}.sql'")
        

          pipeline.expects(:run).in_sequence(s)
          pipeline.expects(:success?).in_sequence(s).returns(true)
          Backup::Logger.expects(:message).in_sequence(s).with('Database::SQLite Complete!')
        end
        
        db.perform!
      end
    end

    context 'when a compressor is configured' do

      before do
        
      end

      it 'should run sqlitedump with compression' do
        
         db.db_name.each do |d|
            Backup::Pipeline.expects(:new).returns(pipeline)
            pipeline.expects(:<<).in_sequence(s).with("echo '.dump' | /path/to/sqlitedump /tmp/#{d}")
            model.expects(:compressor).twice.returns(compressor)
            compressor.expects(:compress_with).yields('gzip', '.gz')
            pipeline.expects(:<<).in_sequence(s).with('gzip')
            pipeline.expects(:<<).in_sequence(s).with("cat > '/dump/path/#{d}.sql.gz'")


            pipeline.expects(:run).in_sequence(s)
            pipeline.expects(:success?).in_sequence(s).returns(true)
            Backup::Logger.expects(:message).in_sequence(s).with('Database::SQLite Complete!')
          end

        db.perform!
      end
    end

    context 'when pipeline command fails' do
      before do
        db.stubs(:db_name).returns(Array.new(["db_a"]))
        db.db_name.each do |d|
          Backup::Pipeline.expects(:new).returns(pipeline)
          pipeline.expects(:<<).in_sequence(s).with("echo '.dump' | /path/to/sqlitedump /tmp/#{d}")
          model.expects(:compressor).returns(nil)
          pipeline.expects(:<<).in_sequence(s).with("cat > '/dump/path/#{d}.sql'")
          pipeline.expects(:run).in_sequence(s)
          pipeline.expects(:success?).in_sequence(s).returns(false)
          pipeline.expects(:error_messages).returns('pipeline_errors')
        end
      end
    
      it 'should raise an error' do
        expect do
          db.perform!
        end.to raise_error(
          Backup::Errors::Database::PipelineError,
          "Database::PipelineError: Database::SQLite Dump Failed!\n" +
          "  pipeline_errors"
        )
      end
    end # context 'when pipeline command fails'

  end # describe '#perform!'

  describe '#sqlitedump' do
    before do
      db.stubs(:sqlitedump_utility).returns(:sqlitedump_utility)
      db.stubs(:db_name).returns(Array[:db_name])
      db.stubs(:db_path).returns(:db_path)
      
    end
    it 'should return the sqlitedump command strings in an array' do
      db.send(:sqlitedump).should be_an_instance_of Array
      db.send(:sqlitedump).length.should >=1
    end
  end
  
  describe '#dump_filename' do
    context 'when @name is set to :all' do
      before { db.name = :all }
      it 'should return an array of strings' do
        db.send(:db_name).should be_an_instance_of Array
      end
    end

    context 'when @name is not set to :all' do
      it 'should return @name' do
        db.send(:db_name)[0].should == 'db1'
        db.send(:db_name).length.should == 1
      end
    end
  end

  describe '#db_name' do
    context 'when @name is set to :all' do
      before { db.name = :all }
      it 'should return an array with filenames of all databases in the given path' do
        db.send(:db_name).should be_an_instance_of Array
      end
    end

    context 'when @name is not set to :all' do
      it 'should return @name' do
        db.send(:db_name)[0].should     == 'db1'
        db.send(:db_name).length.should == 1
      end
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
        Backup::Database::SQLite.any_instance.stubs(:utility)
        Backup::Logger.expects(:warn).with {|err|
          err.should be_an_instance_of Backup::Errors::ConfigurationError
          err.message.should match(
            /Use SQLite#sqlitedump_utility instead/
          )
        }
      end
      after do
        Backup::Database::SQLite.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          sqlite = Backup::Database::SQLite.new(model) do |db|
            db.utility_path = 'foo'
          end
          sqlite.sqlitedump_utility.should == 'foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          sqlite = Backup::Database::SQLite.defaults do |db|
            db.utility_path = 'foo'
          end
          sqlite = Backup::Database::SQLite.new(model)
          sqlite.sqlitedump_utility.should == 'foo'
        end
      end
    end # describe '#utility_path'
  end
end
