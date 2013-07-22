# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::OpenLDAP do
  let(:model) { Backup::Model.new(:test_trigger, 'test model') }
  let(:ldap) do
    Backup::Database::OpenLDAP.new(model) do |ldap|
      #ldap.name            = 'ldap_server'
      ldap.conf_file       = '/etc/openldap/slapd.conf'
      ldap.slapcat_args    = ['-c']
      ldap.slapcat_utility = '/usr/sbin/slapcat'
    end
  end

  it 'should be a subclass of Database::Base' do
    Backup::Database::OpenLDAP.superclass.
      should == Backup::Database::Base
  end

  describe '#initialize' do

    it 'should load pre-configured defaults through Base' do
      Backup::Database::OpenLDAP.any_instance.expects(:load_defaults!)
      ldap
    end

    context 'when options are specified' do
      it 'should have a configuration file' do
        ldap.conf_file.should == '/etc/openldap/slapd.conf'
      end

      it 'should have a slapcat_utility' do
        ldap.slapcat_utility.should == '/usr/sbin/slapcat'
      end

      it 'should have slapcat_args' do
        ldap.slapcat_args.should == ['-c']
      end
    end
  end  # describe '#initialize'
  
  describe '#perform!' do
    let(:s) { sequence '' }
    let(:pipeline) { mock }

    before do
      # superclass actions
      ldap.expects(:prepare!).in_sequence(s)
      ldap.expects(:log!).in_sequence(s)
      ldap.instance_variable_set(:@dump_path, '/dump/path')

      ldap.stubs(:slapcat).returns('slapcat_command')
      ldap.stubs(:dump_filename).returns('dump_filename')
      Backup::Pipeline.expects(:new).returns(pipeline)
    end

    

    context 'when no compressor is configured' do
      before do
        model.expects(:compressor).returns(nil)
      end

      it 'should run slapcat without compression' do
        pipeline.expects(:<<).in_sequence(s).with('slapcat_command')
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/dump/path/dump_filename.ldif'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)
        Backup::Logger.expects(:message).in_sequence(s).with(
          'Database::OpenLDAP Complete!'
        )

        ldap.perform!
      end
    end

    context 'when a compressor is configured' do
      before do
        compressor = mock
        model.expects(:compressor).twice.returns(compressor)
        compressor.expects(:compress_with).yields('gzip', '.gz')
      end

      it 'should run slapcat with compression' do
        pipeline.expects(:<<).in_sequence(s).with('slapcat_command')
        pipeline.expects(:<<).in_sequence(s).with('gzip')
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/dump/path/dump_filename.ldif.gz'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)
        Backup::Logger.expects(:message).in_sequence(s).with(
          'Database::OpenLDAP Complete!'
        )

        ldap.perform!
      end
    end

    context 'when pipeline command fails' do
      before do
        model.expects(:compressor).returns(nil)
        pipeline.stubs(:<<)
        pipeline.expects(:run)
        pipeline.expects(:success?).returns(false)
        pipeline.expects(:error_messages).returns('pipeline_errors')
      end

      it 'should raise an error' do
        expect do
          ldap.perform!
        end.to raise_error(
          Backup::Errors::Database::PipelineError,
          "Database::PipelineError: Database::OpenLDAP Dump Failed!\n" +
          "  pipeline_errors"
        )
      end
    end # context 'when pipeline command fails'

    context 'use_sudo' do
      before do
        ldap.unstub(:slapcat)
        ldap.conf_file = "slapd.conf"
        ldap.slapcat_args = []
        ldap.slapcat_utility = 'slapcat'
        model.expects(:compressor).returns(nil)
      end

      it 'should not call sudo when false' do
        ldap.stubs(:sudo).returns(false)
        pipeline.expects(:<<).in_sequence(s).with("slapcat -f slapd.conf ")
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/dump/path/dump_filename.ldif'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)
        Backup::Logger.expects(:message).in_sequence(s).with(
          'Database::OpenLDAP Complete!'
        )

        ldap.perform!
      end

      it 'should call sudo when true' do
        ldap.stubs(:sudo).returns(true)
        pipeline.expects(:<<).in_sequence(s).with("sudo slapcat -f slapd.conf ") #this does not work for some reason...
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/dump/path/dump_filename.ldif'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)
        Backup::Logger.expects(:message).in_sequence(s).with(
          'Database::OpenLDAP Complete!'
        )

        ldap.perform!
      end


    end # context 'sudo'

  end # describe '#perform!'
end






