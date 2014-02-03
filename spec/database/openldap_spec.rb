# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Database::OpenLDAP do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:db) { Database::OpenLDAP.new(model) }
  let(:s) { sequence '' }

  before do
    Database::OpenLDAP.any_instance.stubs(:utility).
        with(:slapcat).returns('/real/slapcat')
    Database::OpenLDAP.any_instance.stubs(:utility).
        with(:cat).returns('cat')
    Database::OpenLDAP.any_instance.stubs(:utility).
        with(:sudo).returns('sudo')
  end

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Database::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect(db.name).to eq('ldap')
      expect(db.additional_options).to be_nil
    end

    it 'configures the database' do
      db = Database::OpenLDAP.new(model) do |ldap|
        ldap.name               = 'my_name'
        ldap.additional_options = ['--query', '--foo']
      end

      expect( db.name               ).to eq 'my_name'
      expect( db.additional_options ).to eq ['--query', '--foo']
    end
  end # describe '#initialize'

  describe '#perform!' do
    let(:pipeline) { mock }
    let(:compressor) { mock }

    before do
      db.stubs(:slapcat).returns('slapcat_command')
      db.stubs(:dump_path).returns('/tmp/trigger/databases')

      db.expects(:log!).in_sequence(s).with(:started)
      db.expects(:prepare!).in_sequence(s)
    end

    context 'without a compressor' do
      it 'packages the dump without compression' do
        Pipeline.expects(:new).in_sequence(s).returns(pipeline)

        pipeline.expects(:<<).in_sequence(s).with('slapcat_command')

        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/tmp/trigger/databases/OpenLDAP.ldif'"
        )

        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end
    end # context 'without a compressor'

    context 'with a compressor' do
      before do
        model.stubs(:compressor).returns(compressor)
        compressor.stubs(:compress_with).yields('cmp_cmd', '.cmp_ext')
      end

      it 'packages the dump with compression' do
        Pipeline.expects(:new).in_sequence(s).returns(pipeline)

        pipeline.expects(:<<).in_sequence(s).with('slapcat_command')

        pipeline.expects(:<<).in_sequence(s).with('cmp_cmd')

        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/tmp/trigger/databases/OpenLDAP.ldif.cmp_ext'"
        )

        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end
    end # context 'without a compressor'

    context 'when the pipeline fails' do
      before do
        Pipeline.any_instance.stubs(:success?).returns(false)
        Pipeline.any_instance.stubs(:error_messages).returns('error messages')
      end

      it 'raises an error' do
        expect do
          db.perform!
        end.to raise_error(Database::OpenLDAP::Error) {|err|
          expect( err.message ).to eq(
            "Database::OpenLDAP::Error: Dump Failed!\n  error messages"
          )
        }
      end
    end # context 'when the pipeline fails'
  end # describe '#perform!'

  describe '#slapcat' do
    let(:additional_options) {%w[-H ldap:///subtree-dn -a "(!(entryDN:dnSubtreeMatch:=ou=People,dc=example,dc=com))"]}
    let(:conf_file) { "/etc/openldap/slapd.conf" }

    it 'returns full slapcat command built from additional options' do
      db.stubs(:additional_options).returns(additional_options)
      expect( db.send(:slapcat) ).to eq(
        "/real/slapcat -H ldap:///subtree-dn -a \"(!(entryDN:dnSubtreeMatch:=ou=People,dc=example,dc=com))\" "
      )
    end

    it 'returns full slapcat command built from conf file' do
      db.stubs(:conf_file).returns(conf_file)
      expect( db.send(:slapcat) ).to eq(
        "/real/slapcat  -f /etc/openldap/slapd.conf"
      )
    end

    it 'returns full slapcat command built from additional options and conf file' do
      db.stubs(:additional_options).returns(additional_options)
      db.stubs(:conf_file).returns(conf_file)
      expect( db.send(:slapcat) ).to eq(
        "/real/slapcat -H ldap:///subtree-dn -a \"(!(entryDN:dnSubtreeMatch:=ou=People,dc=example,dc=com))\" -f /etc/openldap/slapd.conf"
      )
    end

    it 'supports sudo' do
      db.stubs(:use_sudo).returns("true")
      expect( db.send(:slapcat) ).to eq(
        "sudo -n /real/slapcat  "
      )
    end

    it 'returns full slapcat command built from additional options and conf file and sudo' do
      db.stubs(:additional_options).returns(additional_options)
      db.stubs(:conf_file).returns(conf_file)
      db.stubs(:use_sudo).returns("true")
      expect( db.send(:slapcat) ).to eq(
        "sudo -n /real/slapcat -H ldap:///subtree-dn -a \"(!(entryDN:dnSubtreeMatch:=ou=People,dc=example,dc=com))\" -f /etc/openldap/slapd.conf"
      )
    end
  end  
end
end
