# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Database::Firebird do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:db) { Database::Firebird.new(model) }
  let(:s) { sequence '' }

  before do
    Utilities.stubs(:utility).with(:gbak).returns('gbak')
    Utilities.stubs(:utility).with(:sudo).returns('sudo')
  end

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Database::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( db.database_id        ).to be_nil
      expect( db.name               ).to be_nil
      expect( db.username           ).to be_nil
      expect( db.password           ).to be_nil
      expect( db.sudo_user          ).to be_nil
      expect( db.host               ).to be_nil
      expect( db.path               ).to be_nil
      expect( db.additional_options ).to be_nil
    end

    it 'configures the database' do
      db = Database::Firebird.new(model, :my_id) do |firebird|
        firebird.name               = 'my_name'
        firebird.username           = 'my_username'
        firebird.password           = 'my_password'
        firebird.sudo_user          = 'my_sudo_user'
        firebird.host               = 'my_host'
        firebird.path               = 'my_path'
        firebird.additional_options = 'my_additional_options'
      end

      expect( db.database_id        ).to eq 'my_id'
      expect( db.name               ).to eq 'my_name'
      expect( db.username           ).to eq 'my_username'
      expect( db.password           ).to eq 'my_password'
      expect( db.sudo_user          ).to eq 'my_sudo_user'
      expect( db.host               ).to eq 'my_host'
      expect( db.path               ).to eq 'my_path'
      expect( db.additional_options ).to eq 'my_additional_options'
    end
  end # describe '#initialize'

  describe '#perform!' do

    before do
      db.stubs(:gbak).returns('gbak_command')
      db.stubs(:dump_path).returns('/tmp/trigger/databases')

      db.expects(:log!).in_sequence(s).with(:started)
      db.expects(:prepare!).in_sequence(s)
    end

    context 'without a compressor' do

      it 'dumps the database without compression' do
        db.expects(:run).in_sequence(s).with(
          "gbak_command '/tmp/trigger/databases/Firebird.fbk'"
        )

        FileUtils.expects(:rm_f).never

        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end
    end # context 'without a compressor'

    context 'with a compressor' do
      let(:compressor) { mock }

      before do
        model.stubs(:compressor).returns(compressor)
        compressor.stubs(:compress_with).yields('cmp_cmd', '.cmp_ext')
      end

      it 'dumps the database with compression' do
        db.expects(:run).in_sequence(s).with(
          "gbak_command '/tmp/trigger/databases/Firebird.fbk'"
        )

        db.expects(:run).in_sequence(s).with(
          "cmp_cmd -c '/tmp/trigger/databases/Firebird.fbk' " +
          "> '/tmp/trigger/databases/Firebird.fbk.cmp_ext'"
        )

        FileUtils.expects(:rm_f).in_sequence(s).with(
          '/tmp/trigger/databases/Firebird.fbk'
        )

        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end
    end # context 'with a compressor'
  end # describe '#perform!'

  describe '#gbak' do
    let(:option_methods) {%w[ 
      username_option password_option user_options
    ]}

    it 'returns full gbak command built from all options' do
      option_methods.each {|name| db.stubs(name).returns(name) }
      db.stubs(:name).returns('name')
      db.stubs(:host).returns('host_option')
      db.stubs(:path).returns('path_option')
      db.stubs(:sudo_option).returns('sudo_option')
      expect( db.send(:gbak) ).to eq(
        "sudo_optiongbak 'host_option:path_optionname' #{ option_methods.join(' ') }"
      )
    end

    it 'handles nil values from option methods' do
      option_methods.each {|name| db.stubs(name).returns(nil) }
      db.stubs(:name).returns('name')
      db.stubs(:password_option).returns(nil)
      db.stubs(:sudo_option).returns(nil)
      db.stubs(:host_option).returns(nil)
      db.stubs(:path_option).returns(nil)
      expect( db.send(:gbak) ).to eq(
        "gbak 'name' #{ ' ' * (option_methods.count - 1) }"
      )
    end
  end

  describe 'gbak option methods' do
    describe '#sudo_option' do
      it 'returns argument if specified' do
        expect( db.send(:sudo_option) ).to be_nil

        db.sudo_user = 'my_sudo_user'
        expect( db.send(:sudo_option) ).to eq 'sudo -n -u my_sudo_user '
      end
    end # describe '#sudo_option' do

    describe '#username_option' do
      it 'returns argument if specified' do
        expect( db.send(:username_option) ).to be_nil

        db.username = 'my_username'
        expect( db.send(:username_option) ).to eq "-user my_username"
      end
    end # describe '#username_option' do

    describe '#password_option' do
      it 'returns argument if specified' do
        expect( db.send(:password_option) ).to be_nil

        db.password = 'my_password'
        expect( db.send(:password_option) ).to eq "-pas my_password"
      end
    end # describe '#password_option' do

    describe '#connectivity_options' do
      it 'returns host and path arguments if specified' do
        expect( db.send(:connectivity_options) ).to eq ''

        db.host = 'my_host'
        expect( db.send(:connectivity_options) ).to eq(
          "my_host:"
        )

        db.path = 'my_path'
        expect( db.send(:connectivity_options) ).to eq(
          "my_host:my_path"
        )

        db.host = nil
        expect( db.send(:connectivity_options) ).to eq(
          "my_path"
        )
      end
    end # describe '#connectivity_options'

    describe '#user_options' do
      it 'returns arguments for any #additional_options specified' do
        expect( db.send(:user_options) ).to eq ''

        db.additional_options = ['-e', '-v']
        expect( db.send(:user_options) ).to eq '-e -v'

        db.additional_options = '-e -v'
        expect( db.send(:user_options) ).to eq '-e -v'
      end
    end # describe '#user_options'
  end # describe 'gbak option methods' do

end
end
