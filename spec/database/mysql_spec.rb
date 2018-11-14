require "spec_helper"

module Backup
  describe Database::MySQL do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:db) { Database::MySQL.new(model) }
    let(:s) { sequence "" }

    before do
      allow_any_instance_of(Database::MySQL).to receive(:utility)
        .with(:mysqldump).and_return("mysqldump")
      allow_any_instance_of(Database::MySQL).to receive(:utility)
        .with(:cat).and_return("cat")
      allow_any_instance_of(Database::MySQL).to receive(:utility)
        .with(:innobackupex).and_return("innobackupex")
      allow_any_instance_of(Database::MySQL).to receive(:utility)
        .with(:tar).and_return("tar")
    end

    it_behaves_like "a class that includes Config::Helpers"
    it_behaves_like "a subclass of Database::Base"

    describe "#initialize" do
      it "provides default values" do
        expect(db.database_id).to be_nil
        expect(db.name).to be :all
        expect(db.username).to be_nil
        expect(db.password).to be_nil
        expect(db.host).to be_nil
        expect(db.port).to be_nil
        expect(db.socket).to be_nil
        expect(db.skip_tables).to be_nil
        expect(db.only_tables).to be_nil
        expect(db.additional_options).to be_nil
        expect(db.prepare_options).to be_nil
        expect(db.sudo_user).to be_nil
        expect(db.backup_engine).to eq :mysqldump
        expect(db.prepare_backup).to eq(true)
      end

      it "configures the database" do
        db = Database::MySQL.new(model, :my_id) do |mysql|
          mysql.name               = "my_name"
          mysql.username           = "my_username"
          mysql.password           = "my_password"
          mysql.host               = "my_host"
          mysql.port               = "my_port"
          mysql.socket             = "my_socket"
          mysql.skip_tables        = "my_skip_tables"
          mysql.only_tables        = "my_only_tables"
          mysql.additional_options = "my_additional_options"
          mysql.prepare_options    = "my_prepare_options"
          mysql.sudo_user          = "my_sudo_user"
          mysql.backup_engine      = "my_backup_engine"
          mysql.prepare_backup     = false
        end

        expect(db.database_id).to eq "my_id"
        expect(db.name).to eq "my_name"
        expect(db.username).to eq "my_username"
        expect(db.password).to eq "my_password"
        expect(db.host).to eq "my_host"
        expect(db.port).to eq "my_port"
        expect(db.socket).to eq "my_socket"
        expect(db.skip_tables).to eq "my_skip_tables"
        expect(db.only_tables).to eq "my_only_tables"
        expect(db.additional_options).to eq "my_additional_options"
        expect(db.prepare_options).to eq "my_prepare_options"
        expect(db.sudo_user).to eq "my_sudo_user"
        expect(db.backup_engine).to eq "my_backup_engine"
        expect(db.verbose).to be_falsy
        expect(db.prepare_backup).to eq(false)
      end
    end # describe '#initialize'

    describe "#perform!" do
      let(:pipeline) { double }
      let(:compressor) { double }

      before do
        allow(db).to receive(:mysqldump).and_return("mysqldump_command")
        allow(db).to receive(:dump_path).and_return("/tmp/trigger/databases")

        expect(db).to receive(:log!).ordered.with(:started)
        expect(db).to receive(:prepare!).ordered
      end

      context "without a compressor" do
        it "packages the dump without compression" do
          expect(Pipeline).to receive(:new).ordered.and_return(pipeline)

          expect(pipeline).to receive(:<<).ordered.with("mysqldump_command")

          expect(pipeline).to receive(:<<).ordered.with(
            "cat > '/tmp/trigger/databases/MySQL.sql'"
          )

          expect(pipeline).to receive(:run).ordered
          expect(pipeline).to receive(:success?).ordered.and_return(true)

          expect(db).to receive(:log!).ordered.with(:finished)

          db.perform!
        end
      end # context 'without a compressor'

      context "with a compressor" do
        before do
          allow(model).to receive(:compressor).and_return(compressor)
          allow(compressor).to receive(:compress_with).and_yield("cmp_cmd", ".cmp_ext")
        end

        it "packages the dump with compression" do
          expect(Pipeline).to receive(:new).ordered.and_return(pipeline)

          expect(pipeline).to receive(:<<).ordered.with("mysqldump_command")

          expect(pipeline).to receive(:<<).ordered.with("cmp_cmd")

          expect(pipeline).to receive(:<<).ordered.with(
            "cat > '/tmp/trigger/databases/MySQL.sql.cmp_ext'"
          )

          expect(pipeline).to receive(:run).ordered
          expect(pipeline).to receive(:success?).ordered.and_return(true)

          expect(db).to receive(:log!).ordered.with(:finished)

          db.perform!
        end
      end # context 'without a compressor'

      context "when the pipeline fails" do
        before do
          allow_any_instance_of(Pipeline).to receive(:success?).and_return(false)
          allow_any_instance_of(Pipeline).to receive(:error_messages).and_return("error messages")
        end

        it "raises an error" do
          expect do
            db.perform!
          end.to raise_error(Database::MySQL::Error) { |err|
            expect(err.message).to eq(
              "Database::MySQL::Error: Dump Failed!\n  error messages"
            )
          }
        end
      end # context 'when the pipeline fails'
    end # describe '#perform!'

    context "using alternative engine (innobackupex)" do
      before do
        db.backup_engine = :innobackupex
      end

      describe "#perform!" do
        let(:pipeline) { double }
        let(:compressor) { double }

        before do
          allow(db).to receive(:innobackupex).and_return("innobackupex_command")
          allow(db).to receive(:dump_path).and_return("/tmp/trigger/databases")

          expect(db).to receive(:log!).ordered.with(:started)
          expect(db).to receive(:prepare!).ordered
        end

        context "without a compressor" do
          it "packages the dump without compression" do
            expect(Pipeline).to receive(:new).ordered.and_return(pipeline)

            expect(pipeline).to receive(:<<).ordered.with("innobackupex_command")

            expect(pipeline).to receive(:<<).ordered.with(
              "cat > '/tmp/trigger/databases/MySQL.tar'"
            )

            expect(pipeline).to receive(:run).ordered
            expect(pipeline).to receive(:success?).ordered.and_return(true)

            expect(db).to receive(:log!).ordered.with(:finished)

            db.perform!
          end
        end # context 'without a compressor'

        context "with a compressor" do
          before do
            allow(model).to receive(:compressor).and_return(compressor)
            allow(compressor).to receive(:compress_with).and_yield("cmp_cmd", ".cmp_ext")
          end

          it "packages the dump with compression" do
            expect(Pipeline).to receive(:new).ordered.and_return(pipeline)

            expect(pipeline).to receive(:<<).ordered.with("innobackupex_command")

            expect(pipeline).to receive(:<<).ordered.with("cmp_cmd")

            expect(pipeline).to receive(:<<).ordered.with(
              "cat > '/tmp/trigger/databases/MySQL.tar.cmp_ext'"
            )

            expect(pipeline).to receive(:run).ordered
            expect(pipeline).to receive(:success?).ordered.and_return(true)

            expect(db).to receive(:log!).ordered.with(:finished)

            db.perform!
          end
        end # context 'without a compressor'

        context "when the pipeline fails" do
          before do
            allow_any_instance_of(Pipeline).to receive(:success?).and_return(false)
            allow_any_instance_of(Pipeline).to receive(:error_messages).and_return("error messages")
          end

          it "raises an error" do
            expect do
              db.perform!
            end.to raise_error(Database::MySQL::Error) { |err|
              expect(err.message).to eq(
                "Database::MySQL::Error: Dump Failed!\n  error messages"
              )
            }
          end
        end # context 'when the pipeline fails'
      end # describe '#perform!'
    end # context 'using alternative engine (innobackupex)'

    describe "#mysqldump" do
      let(:option_methods) do
        %w[
          user_options credential_options connectivity_options
          name_option tables_to_dump tables_to_skip
        ]
      end

      it "returns full mysqldump command built from all options" do
        option_methods.each { |name| allow(db).to receive(name).and_return(name) }
        expect(db.send(:mysqldump)).to eq(
          "mysqldump #{option_methods.join(" ")}"
        )
      end

      it "handles nil values from option methods" do
        option_methods.each { |name| allow(db).to receive(name).and_return(nil) }
        expect(db.send(:mysqldump)).to eq(
          "mysqldump #{" " * (option_methods.count - 1)}"
        )
      end
    end # describe '#mysqldump'

    describe "backup engine option methods" do
      describe "#credential_options" do
        it "returns the credentials arguments" do
          expect(db.send(:credential_options)).to eq ""

          db.username = "my_user"
          expect(db.send(:credential_options)).to eq(
            "--user=my_user"
          )

          db.password = "my_password"
          expect(db.send(:credential_options)).to eq(
            "--user=my_user --password=my_password"
          )

          db.username = nil
          expect(db.send(:credential_options)).to eq(
            "--password=my_password"
          )
        end

        it "handles special characters" do
          db.username = "my_user'\""
          db.password = "my_password'\""
          expect(db.send(:credential_options)).to eq(
            "--user=my_user\\'\\\" --password=my_password\\'\\\""
          )
        end
      end # describe '#credential_options'

      describe "#connectivity_options" do
        it "returns only the socket argument if #socket specified" do
          db.host = "my_host"
          db.port = "my_port"
          db.socket = "my_socket"
          expect(db.send(:connectivity_options)).to eq(
            "--socket='my_socket'"
          )
        end

        it "returns host and port arguments if specified" do
          expect(db.send(:connectivity_options)).to eq ""

          db.host = "my_host"
          expect(db.send(:connectivity_options)).to eq(
            "--host='my_host'"
          )

          db.port = "my_port"
          expect(db.send(:connectivity_options)).to eq(
            "--host='my_host' --port='my_port'"
          )

          db.host = nil
          expect(db.send(:connectivity_options)).to eq(
            "--port='my_port'"
          )
        end
      end # describe '#connectivity_options'

      describe "#user_options" do
        it "returns arguments for any #additional_options specified" do
          expect(db.send(:user_options)).to eq ""

          db.additional_options = ["--opt1", "--opt2"]
          expect(db.send(:user_options)).to eq "--opt1 --opt2"

          db.additional_options = "--opta --optb"
          expect(db.send(:user_options)).to eq "--opta --optb"
        end
      end # describe '#user_options'

      describe "#user_prepare_options" do
        it "returns arguments for any #prepare_options specified" do
          expect(db.send(:user_prepare_options)).to eq ""

          db.prepare_options = ["--opt1", "--opt2"]
          expect(db.send(:user_prepare_options)).to eq "--opt1 --opt2"

          db.prepare_options = "--opta --optb"
          expect(db.send(:user_prepare_options)).to eq "--opta --optb"
        end
      end # describe '#user_prepare_options'

      describe "#name_option" do
        it "returns argument to dump all databases if name is :all" do
          expect(db.send(:name_option)).to eq "--all-databases"
        end

        it "returns the database name if name is not :all" do
          db.name = "my_db"
          expect(db.send(:name_option)).to eq "my_db"
        end
      end # describe '#name_option'

      describe "#tables_to_dump" do
        it "returns nil if dumping all databases" do
          db.only_tables = "will be ignored"
          expect(db.send(:tables_to_dump)).to be_nil
        end

        it "returns arguments for only_tables" do
          db.name = "not_all"

          db.only_tables = ["one", "two", "three"]
          expect(db.send(:tables_to_dump)).to eq "one two three"

          db.only_tables = "four five six"
          expect(db.send(:tables_to_dump)).to eq "four five six"
        end
      end # describe '#tables_to_dump'

      describe "#tables_to_skip" do
        specify "when no #skip_tables are specified" do
          expect(db.send(:tables_to_skip)).to eq ""
        end

        context "when dumping all databases" do
          it "returns arguments for all tables given, as given" do
            db.skip_tables = ["my_db.my_table", "foo"]

            # Note that mysqldump will exit(1) if these don't include the db name.
            expect(db.send(:tables_to_skip)).to eq(
              "--ignore-table='my_db.my_table' --ignore-table='foo'"
            )
          end
        end

        context "when a database name is specified" do
          it "will add the database name prefix if missing" do
            db.name = "my_db"
            db.skip_tables = ["my_table", "foo.bar"]

            expect(db.send(:tables_to_skip)).to eq(
              "--ignore-table='my_db.my_table' --ignore-table='foo.bar'"
            )
          end
        end
      end # describe '#tables_to_skip'

      describe "sudo_option" do
        it "does not change the command block by default" do
          expect(db.send(:sudo_option, "foo")).to eq "foo"
        end

        context "with sudo_user" do
          before do
            db.sudo_user = "some_user"
          end

          it "wraps the block around the proper sudo command" do
            expect(db.send(:sudo_option, "foo")).to eq(
              "sudo -s -u some_user -- <<END_OF_SUDO\n" \
              "foo\n" \
              "END_OF_SUDO\n"
            )
          end
        end # context 'with sudo_user' do
      end # describe 'sudo_option'
    end # describe 'backup engine option methods'

    describe "#innobackupex" do
      before do
        allow(db).to receive(:dump_path).and_return("/tmp")
      end

      it "builds command to create backup, prepare for restore and tar to stdout" do
        expect(db.send(:innobackupex).split.join(" ")).to eq(
          "innobackupex --no-timestamp /tmp/MySQL.bkpdir 2> /dev/null && " \
          "innobackupex --apply-log /tmp/MySQL.bkpdir 2> /dev/null && " \
          "tar --remove-files -cf - -C /tmp MySQL.bkpdir"
        )
      end

      context "with verbose option enabled" do
        before do
          db.verbose = true
        end

        it "does not suppress innobackupex STDOUT" do
          expect(db.send(:innobackupex).split.join(" ")).to eq(
            "innobackupex --no-timestamp /tmp/MySQL.bkpdir && " \
            "innobackupex --apply-log /tmp/MySQL.bkpdir && " \
            "tar --remove-files -cf - -C /tmp MySQL.bkpdir"
          )
        end
      end

      context "with prepare_backup option disabled" do
        before do
          db.prepare_backup = false
        end

        it "does not contain apply-log command" do
          expect(db.send(:innobackupex).split.join(" ")).to eq(
            "innobackupex --no-timestamp /tmp/MySQL.bkpdir 2> /dev/null && " \
            "tar --remove-files -cf - -C /tmp MySQL.bkpdir"
          )
        end
      end
    end
  end
end
