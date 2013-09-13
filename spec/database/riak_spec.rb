# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Database::Riak do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:db) { Database::Riak.new(model) }
  let(:s) { sequence '' }

  before do
    Database::Riak.any_instance.stubs(:utility).
        with('riak-admin').returns('riak-admin')
    Database::Riak.any_instance.stubs(:utility).
        with(:sudo).returns('sudo')
    Database::Riak.any_instance.stubs(:utility).
        with(:chown).returns('chown')
  end

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Database::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( db.database_id        ).to be_nil
      expect( db.node               ).to eq 'riak@127.0.0.1'
      expect( db.cookie             ).to eq 'riak'
      expect( db.user               ).to eq 'riak'
    end

    it 'configures the database' do
      db = Database::Riak.new(model, :my_id) do |riak|
        riak.node   = 'my_node'
        riak.cookie = 'my_cookie'
        riak.user   = 'my_user'
      end

      expect( db.database_id ).to eq 'my_id'
      expect( db.node        ).to eq 'my_node'
      expect( db.cookie      ).to eq 'my_cookie'
      expect( db.user        ).to eq 'my_user'
    end
  end # describe '#initialize'


  describe '#perform!' do
    before do
      db.stubs(:dump_path).returns('/tmp/trigger/databases')
      Config.stubs(:user).returns('backup_user')

      db.expects(:log!).in_sequence(s).with(:started)
      db.expects(:prepare!).in_sequence(s)
    end

    context 'with a compressor configured' do
      let(:compressor) { mock }

      before do
        model.stubs(:compressor).returns(compressor)
        compressor.stubs(:compress_with).yields('cmp_cmd', '.cmp_ext')
      end

      it 'dumps the database with compression' do
        db.expects(:run).in_sequence(s).with(
          "sudo -n chown riak '/tmp/trigger/databases'"
        )

        db.expects(:run).in_sequence(s).with(
          "sudo -n -u riak riak-admin backup riak@127.0.0.1 riak " +
          "'/tmp/trigger/databases/Riak' node"
        )

        db.expects(:run).in_sequence(s).with(
          "sudo -n chown -R backup_user '/tmp/trigger/databases'"
        )

        db.expects(:run).in_sequence(s).with(
          "cmp_cmd -c '/tmp/trigger/databases/Riak-riak@127.0.0.1' " +
          "> '/tmp/trigger/databases/Riak-riak@127.0.0.1.cmp_ext'"
        )

        FileUtils.expects(:rm_f).in_sequence(s).with(
          '/tmp/trigger/databases/Riak-riak@127.0.0.1'
        )

        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end
    end # context 'with a compressor configured'

    context 'without a compressor configured' do
      it 'dumps the database without compression' do
        db.expects(:run).in_sequence(s).with(
          "sudo -n chown riak '/tmp/trigger/databases'"
        )

        db.expects(:run).in_sequence(s).with(
          "sudo -n -u riak riak-admin backup riak@127.0.0.1 riak " +
          "'/tmp/trigger/databases/Riak' node"
        )

        db.expects(:run).in_sequence(s).with(
          "sudo -n chown -R backup_user '/tmp/trigger/databases'"
        )

        FileUtils.expects(:rm_f).never

        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end
    end # context 'without a compressor configured'

    it 'ensures dump_path ownership is reclaimed' do
      db.expects(:run).in_sequence(s).with(
        "sudo -n chown riak '/tmp/trigger/databases'"
      )

      db.expects(:run).in_sequence(s).with(
        "sudo -n -u riak riak-admin backup riak@127.0.0.1 riak " +
        "'/tmp/trigger/databases/Riak' node"
      ).raises('an error')

      db.expects(:run).in_sequence(s).with(
        "sudo -n chown -R backup_user '/tmp/trigger/databases'"
      )

      expect do
        db.perform!
      end.to raise_error('an error')
    end
  end # describe '#perform!'

  describe 'deprecations' do
    after { Database::Riak.clear_defaults! }

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

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::Riak.new(model) do |db|
            db.utility_path = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['riak-admin'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::Riak.defaults do |db|
            db.utility_path = '/foo'
          end
          Database::Riak.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['riak-admin'] ).to eq '/foo'
        end
      end
    end # describe '#utility_path'

    describe '#riak_admin_utility' do
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

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::Riak.new(model) do |db|
            db.riak_admin_utility = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['riak-admin'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Database::Riak.defaults do |db|
            db.riak_admin_utility = '/foo'
          end
          Database::Riak.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['riak-admin'] ).to eq '/foo'
        end
      end
    end # describe '#riak_admin_utility'

    describe '#name' do
      before do
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /If you wish to add an identifier/
          )
        }
      end

      context 'when set directly' do
        it 'should issue a deprecation warning' do
          Database::Riak.new(model) do |db|
            db.name = 'foo'
          end
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning' do
          riak = Database::Riak.defaults do |db|
            db.name = 'foo'
          end
          riak = Database::Riak.new(model)
        end
      end
    end # describe '#name'

    describe '#group' do
      before do
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /#group has been deprecated/
          )
        }
      end

      context 'when set directly' do
        it 'should issue a deprecation warning' do
          Database::Riak.new(model) do |db|
            db.group = 'foo'
          end
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning' do
          riak = Database::Riak.defaults do |db|
            db.group = 'foo'
          end
          riak = Database::Riak.new(model)
        end
      end
    end # describe '#group'

  end # describe 'deprecations'

end
end
