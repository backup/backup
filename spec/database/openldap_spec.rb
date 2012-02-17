# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::OpenLDAP do
  let(:model) { Backup::Model.new('foo', 'foo') }
  let(:db) do
    Backup::Database::OpenLDAP.new(model) do |db|
      db.name               = 'mydatabase'
      db.additional_options = ['--query', '--foo']
      db.slapcat_utility  = '/path/to/slapcat'
    end
  end

  describe '#initialize' do
    it 'should read the adapter details correctly' do
      db.name.should               == 'mydatabase'
      db.additional_options.should == ['--query', '--foo']
      db.slapcat_utility.should  == '/path/to/slapcat'
    end

    context 'when options are not set' do
      before do
        Backup::Database::OpenLDAP.any_instance.expects(:utility).
            with('slapcat').returns('/real/slapcat')
      end

      it 'should use default values' do
        db = Backup::Database::OpenLDAP.new(model)

        db.name.should                == 'dump'
        db.additional_options.should  == []
        db.slapcat_utility.should   == '/real/slapcat'
      end
    end

    context 'when configuration defaults have been set' do
      after { Backup::Configuration::Database::OpenLDAP.clear_defaults! }

      it 'should use configuration defaults' do
        Backup::Configuration::Database::OpenLDAP.defaults do |db|
          db.name               = 'db_name'
          db.additional_options = ['--add', '--opts']
          db.slapcat_utility    = '/default/path/to/slapcat'
        end

        db = Backup::Database::OpenLDAP.new(model)
        db.name.should                == 'db_name'
        db.additional_options.should  == ['--add', '--opts']
        db.slapcat_utility.should     == '/default/path/to/slapcat'
      end
    end
  end # describe '#initialize'

  describe '#perform!' do
    let(:s) { sequence '' }
    before do
      # superclass actions
      db.expects(:prepare!).in_sequence(s)
      db.expects(:log!).in_sequence(s)
      db.instance_variable_set(:@dump_path, '/dump/path')
    end

    context 'when no compressor is configured' do
      before do
        model.expects(:compressor).in_sequence(s).returns(nil)
      end

      it 'should run slapcat without compression' do
        db.expects(:run).in_sequence(s).with(
          "/path/to/slapcat > '/dump/path/mydatabase.ldif'"
        )
        db.perform!
      end
    end

    context 'when a compressor is configured' do
      before do
        compressor = mock
        model.expects(:compressor).twice.in_sequence(s).returns(compressor)
        compressor.expects(:compress_with).in_sequence(s).yields('gzip', '.gz')
      end

      it 'should run slapcat with compression' do
        db.expects(:run).in_sequence(s).with(
          "/path/to/slapcat | gzip > '/dump/path/mydatabase.ldif.gz'"
        )
        db.perform!
      end
    end

  end # describe '#perform!'

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
