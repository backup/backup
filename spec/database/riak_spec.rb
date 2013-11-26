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

  it_behaves_like 'a class that includes Config::Helpers'
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

end
end
