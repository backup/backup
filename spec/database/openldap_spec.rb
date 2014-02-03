# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::OpenLDAP do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:db) { Backup::Database::OpenLDAP.new(model) }
  let(:s) { sequence '' }

  before do
    Backup::Database::OpenLDAP.any_instance.stubs(:utility).
        with(:slapcat).returns('/real/slapcat')
  end

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Database::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect(db.name).to eq('ldap')
      expect(db.additional_options).to be_empty
    end

    it 'configures the database' do
      db = Backup::Database::OpenLDAP.new(model) do |ldap|
        ldap.name               = 'my_name'
        ldap.additional_options = ['--query', '--foo']
      end

      expect( db.name               ).to eq 'my_name'
      expect( db.additional_options ).to eq ['--query', '--foo']
    end
  end # describe '#initialize'

  describe '#perform!' do
    before do
      # superclass actions
      db.expects(:log!).in_sequence(s)
      db.expects(:prepare!).in_sequence(s)
      db.instance_variable_set(:@dump_path, '/dump/path')
    end

    context 'when no compressor is configured' do
      before do
        model.expects(:compressor).in_sequence(s).returns(nil)
      end

      it 'should run slapcat without compression' do
        db.expects(:run).in_sequence(s).with(
          "/real/slapcat > '/dump/path/ldap.ldif'"
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
          "/real/slapcat | gzip > '/dump/path/ldap.ldif.gz'"
        )
        db.perform!
      end
    end

  end # describe '#perform!'
end
