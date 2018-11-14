require "spec_helper"

module Backup
  describe Database::Riak do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:db) { Database::Riak.new(model) }
    let(:s) { sequence "" }

    before do
      allow_any_instance_of(Database::Riak).to receive(:utility)
        .with("riak-admin").and_return("riak-admin")
      allow_any_instance_of(Database::Riak).to receive(:utility)
        .with(:sudo).and_return("sudo")
      allow_any_instance_of(Database::Riak).to receive(:utility)
        .with(:chown).and_return("chown")
    end

    it_behaves_like "a class that includes Config::Helpers"
    it_behaves_like "a subclass of Database::Base"

    describe "#initialize" do
      it "provides default values" do
        expect(db.database_id).to be_nil
        expect(db.node).to eq "riak@127.0.0.1"
        expect(db.cookie).to eq "riak"
        expect(db.user).to eq "riak"
      end

      it "configures the database" do
        db = Database::Riak.new(model, :my_id) do |riak|
          riak.node   = "my_node"
          riak.cookie = "my_cookie"
          riak.user   = "my_user"
        end

        expect(db.database_id).to eq "my_id"
        expect(db.node).to eq "my_node"
        expect(db.cookie).to eq "my_cookie"
        expect(db.user).to eq "my_user"
      end
    end # describe '#initialize'

    describe "#perform!" do
      before do
        allow(db).to receive(:dump_path).and_return("/tmp/trigger/databases")
        allow(Config).to receive(:user).and_return("backup_user")

        expect(db).to receive(:log!).ordered.with(:started)
        expect(db).to receive(:prepare!).ordered
      end

      context "with a compressor configured" do
        let(:compressor) { double }

        before do
          allow(model).to receive(:compressor).and_return(compressor)
          allow(compressor).to receive(:compress_with).and_yield("cmp_cmd", ".cmp_ext")
        end

        it "dumps the database with compression" do
          expect(db).to receive(:run).ordered.with(
            "sudo -n chown riak '/tmp/trigger/databases'"
          )

          expect(db).to receive(:run).ordered.with(
            "sudo -n -u riak riak-admin backup riak@127.0.0.1 riak " \
            "'/tmp/trigger/databases/Riak' node"
          )

          expect(db).to receive(:run).ordered.with(
            "sudo -n chown -R backup_user '/tmp/trigger/databases'"
          )

          expect(db).to receive(:run).ordered.with(
            "cmp_cmd -c '/tmp/trigger/databases/Riak-riak@127.0.0.1' " \
            "> '/tmp/trigger/databases/Riak-riak@127.0.0.1.cmp_ext'"
          )

          expect(FileUtils).to receive(:rm_f).ordered.with(
            "/tmp/trigger/databases/Riak-riak@127.0.0.1"
          )

          expect(db).to receive(:log!).ordered.with(:finished)

          db.perform!
        end
      end # context 'with a compressor configured'

      context "without a compressor configured" do
        it "dumps the database without compression" do
          expect(db).to receive(:run).ordered.with(
            "sudo -n chown riak '/tmp/trigger/databases'"
          )

          expect(db).to receive(:run).ordered.with(
            "sudo -n -u riak riak-admin backup riak@127.0.0.1 riak " \
            "'/tmp/trigger/databases/Riak' node"
          )

          expect(db).to receive(:run).ordered.with(
            "sudo -n chown -R backup_user '/tmp/trigger/databases'"
          )

          expect(FileUtils).to receive(:rm_f).never

          expect(db).to receive(:log!).ordered.with(:finished)

          db.perform!
        end
      end # context 'without a compressor configured'

      it "ensures dump_path ownership is reclaimed" do
        expect(db).to receive(:run).ordered.with(
          "sudo -n chown riak '/tmp/trigger/databases'"
        )

        expect(db).to receive(:run).ordered.with(
          "sudo -n -u riak riak-admin backup riak@127.0.0.1 riak " \
          "'/tmp/trigger/databases/Riak' node"
        ).and_raise("an error")

        expect(db).to receive(:run).ordered.with(
          "sudo -n chown -R backup_user '/tmp/trigger/databases'"
        )

        expect do
          db.perform!
        end.to raise_error("an error")
      end
    end # describe '#perform!'
  end
end
