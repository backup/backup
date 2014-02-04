# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

<<<<<<< HEAD
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
=======
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
>>>>>>> 8c7c8f032b91180bbb9a437c0dfa0dbc69709929
    end
  end # describe '#initialize'

  describe '#perform!' do
<<<<<<< HEAD
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

=======
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
>>>>>>> 8c7c8f032b91180bbb9a437c0dfa0dbc69709929
end
