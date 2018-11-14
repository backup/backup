require "spec_helper"

module Backup
  describe Database::SQLite do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:db) do
      Database::SQLite.new(model) do |db|
        db.path = "/tmp/db1.sqlite3"
        db.sqlitedump_utility = "/path/to/sqlitedump"
      end
    end

    before do
      allow_any_instance_of(Database::SQLite).to receive(:utility)
        .with(:sqlitedump).and_return("sqlitedump")
    end

    it_behaves_like "a class that includes Config::Helpers"
    it_behaves_like "a subclass of Database::Base"

    describe "#initialize" do
      it "should load pre-configured defaults through Base" do
        expect_any_instance_of(Database::SQLite).to receive(:load_defaults!)
        db
      end

      it "should pass the model reference to Base" do
        expect(db.instance_variable_get(:@model)).to eq(model)
      end

      context "when no pre-configured defaults have been set" do
        context "when options are specified" do
          it "should use the given values" do
            expect(db.sqlitedump_utility).to eq("/path/to/sqlitedump")
          end
        end
      end # context 'when no pre-configured defaults have been set'

      context "when pre-configured defaults have been set" do
        before do
          Database::SQLite.defaults do |db|
            db.sqlitedump_utility = "/default/path/to/sqlitedump"
          end
        end

        after { Database::SQLite.clear_defaults! }

        context "when options are specified" do
          it "should override the pre-configured defaults" do
            expect(db.sqlitedump_utility).to eq("/path/to/sqlitedump")
          end
        end

        context "when options are not specified" do
          it "should use the pre-configured defaults" do
            db = Database::SQLite.new(model)

            expect(db.sqlitedump_utility).to eq("/default/path/to/sqlitedump")
          end
        end
      end # context 'when no pre-configured defaults have been set'
    end # describe '#initialize'

    describe "#perform!" do
      let(:pipeline) { double }
      let(:compressor) { double }

      before do
        # superclass actions
        db.instance_variable_set(:@dump_path, "/dump/path")
        allow(db).to receive(:dump_filename).and_return("dump_filename")

        expect(db).to receive(:log!).ordered.with(:started)
        expect(db).to receive(:prepare!).ordered
      end

      context "when no compressor is configured" do
        it "should run sqlitedump without compression" do
          expect(Pipeline).to receive(:new).and_return(pipeline)
          expect(pipeline).to receive(:<<).ordered.with("echo '.dump' | /path/to/sqlitedump /tmp/db1.sqlite3")
          expect(model).to receive(:compressor).and_return(nil)
          expect(pipeline).to receive(:<<).ordered.with("cat > '/dump/path/dump_filename.sql'")

          expect(pipeline).to receive(:run).ordered
          expect(pipeline).to receive(:success?).ordered.and_return(true)

          expect(db).to receive(:log!).ordered.with(:finished)

          db.perform!
        end
      end

      context "when a compressor is configured" do
        it "should run sqlitedump with compression" do
          expect(Pipeline).to receive(:new).and_return(pipeline)
          expect(pipeline).to receive(:<<).ordered.with("echo '.dump' | /path/to/sqlitedump /tmp/db1.sqlite3")
          expect(model).to receive(:compressor).twice.and_return(compressor)
          expect(compressor).to receive(:compress_with).and_yield("gzip", ".gz")
          expect(pipeline).to receive(:<<).ordered.with("gzip")
          expect(pipeline).to receive(:<<).ordered.with("cat > '/dump/path/dump_filename.sql.gz'")

          expect(pipeline).to receive(:run).ordered
          expect(pipeline).to receive(:success?).ordered.and_return(true)

          expect(db).to receive(:log!).ordered.with(:finished)

          db.perform!
        end
      end

      context "when pipeline command fails" do
        before do
          expect(Pipeline).to receive(:new).and_return(pipeline)
          expect(pipeline).to receive(:<<).ordered.with("echo '.dump' | /path/to/sqlitedump /tmp/db1.sqlite3")
          expect(model).to receive(:compressor).and_return(nil)
          expect(pipeline).to receive(:<<).ordered.with("cat > '/dump/path/dump_filename.sql'")
          expect(pipeline).to receive(:run).ordered
          expect(pipeline).to receive(:success?).ordered.and_return(false)
          expect(pipeline).to receive(:error_messages).and_return("pipeline_errors")
        end

        it "should raise an error" do
          expect do
            db.perform!
          end.to raise_error(
            Database::SQLite::Error,
            "Database::SQLite::Error: Database::SQLite Dump Failed!\n" \
            "  pipeline_errors"
          )
        end
      end # context 'when pipeline command fails'
    end # describe '#perform!'
  end
end
