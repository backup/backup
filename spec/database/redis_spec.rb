require "spec_helper"

module Backup
  describe Database::Redis do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:required_config) do
      proc do |redis|
        redis.rdb_path = "rdb_path_required_for_copy_mode"
      end
    end
    let(:db) { Database::Redis.new(model, &required_config) }
    let(:s) { sequence "" }

    before do
      allow_any_instance_of(Database::Redis).to receive(:utility)
        .with("redis-cli").and_return("redis-cli")
      allow_any_instance_of(Database::Redis).to receive(:utility)
        .with(:cat).and_return("cat")
    end

    it_behaves_like "a class that includes Config::Helpers" do
      let(:default_overrides) { { "mode" => :sync } }
      let(:new_overrides) { { "mode" => :copy } }
    end
    it_behaves_like "a subclass of Database::Base"

    describe "#initialize" do
      it "provides default values" do
        expect(db.database_id).to be_nil
        expect(db.mode).to eq :copy
        expect(db.rdb_path).to eq "rdb_path_required_for_copy_mode"
        expect(db.invoke_save).to be_nil
        expect(db.host).to be_nil
        expect(db.port).to be_nil
        expect(db.socket).to be_nil
        expect(db.password).to be_nil
        expect(db.additional_options).to be_nil
      end

      it "configures the database" do
        db = Database::Redis.new(model, :my_id) do |redis|
          redis.mode               = :copy
          redis.rdb_path           = "my_path"
          redis.invoke_save        = true
          redis.host               = "my_host"
          redis.port               = "my_port"
          redis.socket             = "my_socket"
          redis.password           = "my_password"
          redis.additional_options = "my_additional_options"
        end

        expect(db.database_id).to eq "my_id"
        expect(db.mode).to eq :copy
        expect(db.rdb_path).to eq "my_path"
        expect(db.invoke_save).to be true
        expect(db.host).to eq "my_host"
        expect(db.port).to eq "my_port"
        expect(db.socket).to eq "my_socket"
        expect(db.password).to eq "my_password"
        expect(db.additional_options).to eq "my_additional_options"
      end

      it "raises an error if mode is invalid" do
        expect do
          Database::Redis.new(model) do |redis|
            redis.mode = "sync" # symbol required
          end
        end.to raise_error(Database::Redis::Error) { |err|
          expect(err.message).to match(/not a valid mode/)
        }
      end

      it "raises an error if rdb_path is not set for :copy mode" do
        expect do
          Database::Redis.new(model) do |redis|
            redis.rdb_path = nil
          end
        end.to raise_error(Database::Redis::Error) { |err|
          expect(err.message).to match(/`rdb_path` must be set/)
        }
      end
    end # describe '#initialize'

    describe "#perform!" do
      before do
        expect(db).to receive(:log!).ordered.with(:started)
        expect(db).to receive(:prepare!).ordered
      end

      context "when mode is :sync" do
        before do
          db.mode = :sync
        end

        it "uses sync!" do
          expect(Logger).to receive(:configure).ordered
          expect(db).to receive(:sync!).ordered
          expect(db).to receive(:log!).ordered.with(:finished)
          db.perform!
        end
      end

      context "when mode is :copy" do
        before do
          db.mode = :copy
        end

        context "when :invoke_save is false" do
          it "calls copy! without save!" do
            expect(Logger).to receive(:configure).never
            expect(db).to receive(:save!).never
            expect(db).to receive(:copy!).ordered
            expect(db).to receive(:log!).ordered.with(:finished)
            db.perform!
          end
        end

        context "when :invoke_save is true" do
          before do
            db.invoke_save = true
          end

          it "calls save! before copy!" do
            expect(Logger).to receive(:configure).never
            expect(db).to receive(:save!).ordered
            expect(db).to receive(:copy!).ordered
            expect(db).to receive(:log!).ordered.with(:finished)
            db.perform!
          end
        end
      end
    end # describe '#perform!'

    describe "#sync!" do
      let(:pipeline) { double }
      let(:compressor) { double }

      before do
        allow(db).to receive(:redis_cli_cmd).and_return("redis_cli_cmd")
        allow(db).to receive(:dump_path).and_return("/tmp/trigger/databases")
      end

      context "without a compressor" do
        it "packages the dump without compression" do
          expect(Pipeline).to receive(:new).ordered.and_return(pipeline)

          expect(pipeline).to receive(:<<).ordered.with("redis_cli_cmd --rdb -")

          expect(pipeline).to receive(:<<).ordered.with(
            "cat > '/tmp/trigger/databases/Redis.rdb'"
          )

          expect(pipeline).to receive(:run).ordered
          expect(pipeline).to receive(:success?).ordered.and_return(true)

          db.send(:sync!)
        end
      end # context 'without a compressor'

      context "with a compressor" do
        before do
          allow(model).to receive(:compressor).and_return(compressor)
          allow(compressor).to receive(:compress_with).and_yield("cmp_cmd", ".cmp_ext")
        end

        it "packages the dump with compression" do
          expect(Pipeline).to receive(:new).ordered.and_return(pipeline)

          expect(pipeline).to receive(:<<).ordered.with("redis_cli_cmd --rdb -")

          expect(pipeline).to receive(:<<).ordered.with("cmp_cmd")

          expect(pipeline).to receive(:<<).ordered.with(
            "cat > '/tmp/trigger/databases/Redis.rdb.cmp_ext'"
          )

          expect(pipeline).to receive(:run).ordered
          expect(pipeline).to receive(:success?).ordered.and_return(true)

          db.send(:sync!)
        end
      end # context 'without a compressor'

      context "when the pipeline fails" do
        before do
          allow_any_instance_of(Pipeline).to receive(:success?).and_return(false)
          allow_any_instance_of(Pipeline).to receive(:error_messages).and_return("error messages")
        end

        it "raises an error" do
          expect do
            db.send(:sync!)
          end.to raise_error(Database::Redis::Error) { |err|
            expect(err.message).to eq(
              "Database::Redis::Error: Dump Failed!\n  error messages"
            )
          }
        end
      end # context 'when the pipeline fails'
    end # describe '#sync!'

    describe "#save!" do
      before do
        allow(db).to receive(:redis_cli_cmd).and_return("redis_cli_cmd")
      end

      # the redis docs say this returns "+OK\n", although it appears
      # to only return "OK\n". Utilities#run strips the STDOUT returned,
      # so a successful response should =~ /OK$/

      specify "when response is OK" do
        expect(db).to receive(:run).with("redis_cli_cmd SAVE").and_return("+OK")
        db.send(:save!)
      end

      specify "when response is not OK" do
        expect(db).to receive(:run).with("redis_cli_cmd SAVE").and_return("No OK Returned")
        expect do
          db.send(:save!)
        end.to raise_error(Database::Redis::Error) { |err|
          expect(err.message).to match(/Failed to invoke the `SAVE` command/)
          expect(err.message).to match(/Response was: No OK Returned/)
        }
      end

      specify "retries if save already in progress" do
        expect(db).to receive(:run).with("redis_cli_cmd SAVE").exactly(5).times
          .and_return("Background save already in progress")
        expect(db).to receive(:sleep).with(5).exactly(4).times
        expect do
          db.send(:save!)
        end.to raise_error(Database::Redis::Error) { |err|
          expect(err.message).to match(/Failed to invoke the `SAVE` command/)
          expect(err.message).to match(
            /Response was: Background save already in progress/
          )
        }
      end
    end # describe '#save!'

    describe "#copy!" do
      before do
        allow(db).to receive(:dump_path).and_return("/tmp/trigger/databases")
        db.rdb_path = "/var/lib/redis/dump.rdb"
      end

      context "when the redis dump file exists" do
        before do
          expect(File).to receive(:exist?).ordered.with(
            "/var/lib/redis/dump.rdb"
          ).and_return(true)
        end

        context "when a compressor is configured" do
          let(:compressor) { double }

          before do
            allow(model).to receive(:compressor).and_return(compressor)
            allow(compressor).to receive(:compress_with).and_yield("cmp_cmd", ".cmp_ext")
          end

          it "should copy the redis dump file with compression" do
            expect(db).to receive(:run).ordered.with(
              "cmp_cmd -c '/var/lib/redis/dump.rdb' > " \
              "'/tmp/trigger/databases/Redis.rdb.cmp_ext'"
            )
            expect(FileUtils).to receive(:cp).never

            db.send(:copy!)
          end
        end # context 'when a compressor is configured'

        context "when no compressor is configured" do
          it "should copy the redis dump file without compression" do
            expect(FileUtils).to receive(:cp).ordered.with(
              "/var/lib/redis/dump.rdb", "/tmp/trigger/databases/Redis.rdb"
            )
            expect(db).to receive(:run).never

            db.send(:copy!)
          end
        end # context 'when no compressor is configured'
      end # context 'when the redis dump file exists'

      context "when the redis dump file does not exist" do
        it "raises an error" do
          expect(File).to receive(:exist?).ordered.with(
            "/var/lib/redis/dump.rdb"
          ).and_return(false)

          expect do
            db.send(:copy!)
          end.to raise_error(Database::Redis::Error)
        end
      end # context 'when the redis dump file does not exist'
    end # describe '#copy!'

    describe "#redis_cli_cmd" do
      let(:option_methods) do
        %w[
          password_option connectivity_options user_options
        ]
      end

      it "returns full redis-cli command built from all options" do
        option_methods.each { |name| allow(db).to receive(name).and_return(name) }
        expect(db.send(:redis_cli_cmd)).to eq(
          "redis-cli #{option_methods.join(" ")}"
        )
      end

      it "handles nil values from option methods" do
        option_methods.each { |name| allow(db).to receive(name).and_return(nil) }
        expect(db.send(:redis_cli_cmd)).to eq(
          "redis-cli #{(" " * (option_methods.count - 1))}"
        )
      end
    end # describe '#redis_cli_cmd'

    describe "redis_cli_cmd option methods" do
      describe "#password_option" do
        it "returns argument if specified" do
          expect(db.send(:password_option)).to be_nil

          db.password = "my_password"
          expect(db.send(:password_option)).to eq "-a 'my_password'"
        end
      end # describe '#password_option'

      describe "#connectivity_options" do
        it "returns only the socket argument if #socket specified" do
          db.host = "my_host"
          db.port = "my_port"
          db.socket = "my_socket"
          expect(db.send(:connectivity_options)).to eq(
            "-s 'my_socket'"
          )
        end

        it "returns host and port arguments if specified" do
          expect(db.send(:connectivity_options)).to eq ""

          db.host = "my_host"
          expect(db.send(:connectivity_options)).to eq(
            "-h 'my_host'"
          )

          db.port = "my_port"
          expect(db.send(:connectivity_options)).to eq(
            "-h 'my_host' -p 'my_port'"
          )

          db.host = nil
          expect(db.send(:connectivity_options)).to eq(
            "-p 'my_port'"
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
    end # describe 'redis_cli_cmd option methods'
  end
end
