# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Database::PostgreSQL do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:db) { Database::PostgreSQL.new(model) }
  let(:s) { sequence '' }

  before do
    Utilities.stubs(:utility).with(:pg_dump).returns('pg_dump')
    Utilities.stubs(:utility).with(:pg_dumpall).returns('pg_dumpall')
    Utilities.stubs(:utility).with(:cat).returns('cat')
    Utilities.stubs(:utility).with(:sudo).returns('sudo')
  end

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Database::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( db.database_id        ).to be_nil
      expect( db.name               ).to eq :all
      expect( db.username           ).to be_nil
      expect( db.password           ).to be_nil
      expect( db.sudo_user          ).to be_nil
      expect( db.host               ).to be_nil
      expect( db.port               ).to be_nil
      expect( db.socket             ).to be_nil
      expect( db.skip_tables        ).to be_nil
      expect( db.only_tables        ).to be_nil
      expect( db.additional_options ).to be_nil
    end

    it 'configures the database' do
      db = Database::PostgreSQL.new(model, :my_id) do |pgsql|
        pgsql.name               = 'my_name'
        pgsql.username           = 'my_username'
        pgsql.password           = 'my_password'
        pgsql.sudo_user          = 'my_sudo_user'
        pgsql.host               = 'my_host'
        pgsql.port               = 'my_port'
        pgsql.socket             = 'my_socket'
        pgsql.skip_tables        = 'my_skip_tables'
        pgsql.only_tables        = 'my_only_tables'
        pgsql.additional_options = 'my_additional_options'
      end

      expect( db.database_id        ).to eq 'my_id'
      expect( db.name               ).to eq 'my_name'
      expect( db.username           ).to eq 'my_username'
      expect( db.password           ).to eq 'my_password'
      expect( db.sudo_user          ).to eq 'my_sudo_user'
      expect( db.host               ).to eq 'my_host'
      expect( db.port               ).to eq 'my_port'
      expect( db.socket             ).to eq 'my_socket'
      expect( db.skip_tables        ).to eq 'my_skip_tables'
      expect( db.only_tables        ).to eq 'my_only_tables'
      expect( db.additional_options ).to eq 'my_additional_options'
    end
  end # describe '#initialize'

  describe '#perform!' do
    let(:pipeline) { mock }
    let(:compressor) { mock }

    before do
      db.stubs(:pgdump).returns('pgdump_command')
      db.stubs(:pgdumpall).returns('pgdumpall_command')
      db.stubs(:dump_path).returns('/tmp/trigger/databases')

      db.expects(:log!).in_sequence(s).with(:started)
      db.expects(:prepare!).in_sequence(s)
    end

    context 'without a compressor' do
      it 'packages the dump without compression' do
        Pipeline.expects(:new).in_sequence(s).returns(pipeline)

        pipeline.expects(:<<).in_sequence(s).with('pgdumpall_command')

        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/tmp/trigger/databases/PostgreSQL.sql'"
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

        pipeline.expects(:<<).in_sequence(s).with('pgdumpall_command')

        pipeline.expects(:<<).in_sequence(s).with('cmp_cmd')

        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/tmp/trigger/databases/PostgreSQL.sql.cmp_ext'"
        )

        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end
    end # context 'without a compressor'

    context 'when #name is set' do
      before do
        db.name = 'my_db'
      end

      it 'uses the pg_dump command' do
        Pipeline.expects(:new).in_sequence(s).returns(pipeline)

        pipeline.expects(:<<).in_sequence(s).with('pgdump_command')

        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '/tmp/trigger/databases/PostgreSQL.sql'"
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
        end.to raise_error(Database::PostgreSQL::Error) {|err|
          expect( err.message ).to eq(
            "Database::PostgreSQL::Error: Dump Failed!\n  error messages"
          )
        }
      end
    end # context 'when the pipeline fails'

  end # describe '#perform!'

  describe '#pgdump' do
    let(:option_methods) {%w[
      username_option connectivity_options
      user_options tables_to_dump tables_to_skip name
    ]}
    # password_option and sudo_option leave no leading space if it's not used

    it 'returns full pg_dump command built from all options' do
      option_methods.each {|name| db.stubs(name).returns(name) }
      db.stubs(:password_option).returns('password_option')
      db.stubs(:sudo_option).returns('sudo_option')
      expect( db.send(:pgdump) ).to eq(
        "password_optionsudo_optionpg_dump #{ option_methods.join(' ') }"
      )
    end

    it 'handles nil values from option methods' do
      option_methods.each {|name| db.stubs(name).returns(nil) }
      db.stubs(:password_option).returns(nil)
      db.stubs(:sudo_option).returns(nil)
      expect( db.send(:pgdump) ).to eq(
        "pg_dump #{ ' ' * (option_methods.count - 1) }"
      )
    end
  end # describe '#pgdump'

  describe '#pgdumpall' do
    let(:option_methods) {%w[
      username_option connectivity_options user_options
    ]}
    # password_option and sudo_option leave no leading space if it's not used

    it 'returns full pg_dump command built from all options' do
      option_methods.each {|name| db.stubs(name).returns(name) }
      db.stubs(:password_option).returns('password_option')
      db.stubs(:sudo_option).returns('sudo_option')
      expect( db.send(:pgdumpall) ).to eq(
        "password_optionsudo_optionpg_dumpall #{ option_methods.join(' ') }"
      )
    end

    it 'handles nil values from option methods' do
      option_methods.each {|name| db.stubs(name).returns(nil) }
      db.stubs(:password_option).returns(nil)
      db.stubs(:sudo_option).returns(nil)
      expect( db.send(:pgdumpall) ).to eq(
        "pg_dumpall #{ ' ' * (option_methods.count - 1) }"
      )
    end
  end # describe '#pgdumpall'

  describe 'pgdump option methods' do

    describe '#password_option' do
      it 'returns syntax to set environment variable' do
        expect( db.send(:password_option) ).to be_nil

        db.password = 'my_password'
        expect( db.send(:password_option) ).to eq "PGPASSWORD='my_password' "
      end
    end # describe '#password_option'

    describe '#sudo_option' do
      it 'returns argument if specified' do
        expect( db.send(:sudo_option) ).to be_nil

        db.sudo_user = 'my_sudo_user'
        expect( db.send(:sudo_option) ).to eq 'sudo -n -u my_sudo_user '
      end
    end # describe '#sudo_option'

    describe '#username_option' do
      it 'returns argument if specified' do
        expect( db.send(:username_option) ).to be_nil

        db.username = 'my_username'
        expect( db.send(:username_option) ).to eq "--username='my_username'"
      end
    end # describe '#username_option'

    describe '#connectivity_options' do
      it 'returns only the socket argument if #socket specified' do
        db.host = 'my_host'
        db.port = 'my_port'
        db.socket = 'my_socket'
        # pgdump uses --host to specify a socket
        expect( db.send(:connectivity_options) ).to eq(
          "--host='my_socket'"
        )
      end

      it 'returns host and port arguments if specified' do
        expect( db.send(:connectivity_options) ).to eq ''

        db.host = 'my_host'
        expect( db.send(:connectivity_options) ).to eq(
          "--host='my_host'"
        )

        db.port = 'my_port'
        expect( db.send(:connectivity_options) ).to eq(
          "--host='my_host' --port='my_port'"
        )

        db.host = nil
        expect( db.send(:connectivity_options) ).to eq(
          "--port='my_port'"
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

    describe '#tables_to_dump' do
      it 'returns arguments for only_tables' do
        expect( db.send(:tables_to_dump) ).to eq ''

        db.only_tables = ['one', 'two']
        expect( db.send(:tables_to_dump) ).to eq(
          "--table='one' --table='two'"
        )

        db.only_tables = 'three four'
        expect( db.send(:tables_to_dump) ).to eq(
          "--table='three four'"
        )
      end
    end # describe '#tables_to_dump'

    describe '#tables_to_skip' do
      it 'returns arguments for skip_tables' do
        expect( db.send(:tables_to_skip) ).to eq ''

        db.skip_tables = ['one', 'two']
        expect( db.send(:tables_to_skip) ).to eq(
          "--exclude-table='one' --exclude-table='two'"
        )

        db.skip_tables = 'three four'
        expect( db.send(:tables_to_skip) ).to eq(
          "--exclude-table='three four'"
        )
      end
    end # describe '#tables_to_dump'

  end # describe 'pgdump option methods'

  describe 'deprecations' do

    describe '#utility_path' do
      before do
        # to satisfy Utilities.configure
        File.stubs(:executable?).with('/foo').returns(true)
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use Backup::Utilities\.configure instead/
          )
        }
      end
      after do
        Database::PostgreSQL.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::PostgreSQL.new(model) do |db|
            db.utility_path = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['pg_dump'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::PostgreSQL.defaults do |db|
            db.utility_path = '/foo'
          end
          Database::PostgreSQL.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['pg_dump'] ).to eq '/foo'
        end
      end
    end # describe '#utility_path'

    describe '#pg_dump_utility' do
      before do
        # to satisfy Utilities.configure
        File.stubs(:executable?).with('/foo').returns(true)
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use Backup::Utilities\.configure instead/
          )
        }
      end
      after do
        Database::PostgreSQL.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::PostgreSQL.new(model) do |db|
            db.pg_dump_utility = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['pg_dump'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::PostgreSQL.defaults do |db|
            db.pg_dump_utility = '/foo'
          end
          Database::PostgreSQL.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['pg_dump'] ).to eq '/foo'
        end
      end
    end # describe '#pg_dump_utility'

  end # describe 'deprecations' do

end
end
