require "spec_helper"

module Backup
  describe Storage::SFTP do
    let(:model)   { Model.new(:test_trigger, "test label") }
    let(:storage) { Storage::SFTP.new(model) }
    let(:s) { sequence "" }

    it_behaves_like "a class that includes Config::Helpers"
    it_behaves_like "a subclass of Storage::Base"
    it_behaves_like "a storage that cycles"

    describe "#initialize" do
      it "provides default values" do
        expect(storage.storage_id).to be_nil
        expect(storage.keep).to be_nil
        expect(storage.username).to be_nil
        expect(storage.password).to be_nil
        expect(storage.ssh_options).to eq({})
        expect(storage.ip).to be_nil
        expect(storage.port).to be 22
        expect(storage.path).to eq "backups"
      end

      it "configures the storage" do
        storage = Storage::SFTP.new(model, :my_id) do |sftp|
          sftp.keep = 2
          sftp.username     = "my_username"
          sftp.password     = "my_password"
          sftp.ssh_options  = { keys: ["my/key"] }
          sftp.ip           = "my_host"
          sftp.port         = 123
          sftp.path         = "my/path"
        end

        expect(storage.storage_id).to eq "my_id"
        expect(storage.keep).to be 2
        expect(storage.username).to eq "my_username"
        expect(storage.password).to eq "my_password"
        expect(storage.ssh_options).to eq keys: ["my/key"]
        expect(storage.ip).to eq "my_host"
        expect(storage.port).to be 123
        expect(storage.path).to eq "my/path"
      end

      it "converts a tilde path to a relative path" do
        storage = Storage::SFTP.new(model) do |sftp|
          sftp.path = "~/my/path"
        end
        expect(storage.path).to eq "my/path"
      end

      it "does not alter an absolute path" do
        storage = Storage::SFTP.new(model) do |sftp|
          sftp.path = "/my/path"
        end
        expect(storage.path).to eq "/my/path"
      end
    end # describe '#initialize'

    describe "#connection" do
      let(:connection) { double }

      before do
        storage.ip = "123.45.678.90"
        storage.username = "my_user"
        storage.password = "my_pass"
        storage.ssh_options = { keys: ["my/key"] }
      end

      it "yields a connection to the remote server" do
        expect(Net::SFTP).to receive(:start).with(
          "123.45.678.90", "my_user", password: "my_pass", port: 22,
          keys: ["my/key"]
        ).and_yield(connection)

        storage.send(:connection) do |sftp|
          expect(sftp).to be connection
        end
      end
    end # describe '#connection'

    describe "#transfer!" do
      let(:connection) { double }
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join("my/path/test_trigger", timestamp) }

      before do
        Timecop.freeze
        storage.package.time = timestamp
        allow(storage.package).to receive(:filenames).and_return(
          ["test_trigger.tar-aa", "test_trigger.tar-ab"]
        )
        storage.ip = "123.45.678.90"
        storage.path = "my/path"
      end

      after { Timecop.return }

      it "transfers the package files" do
        expect(storage).to receive(:connection).ordered.and_yield(connection)

        expect(storage).to receive(:create_remote_path).ordered.with(connection)

        src = File.join(Config.tmp_path, "test_trigger.tar-aa")
        dest = File.join(remote_path, "test_trigger.tar-aa")

        expect(Logger).to receive(:info).ordered
          .with("Storing '123.45.678.90:#{dest}'...")

        expect(connection).to receive(:upload!).ordered.with(src, dest)

        src = File.join(Config.tmp_path, "test_trigger.tar-ab")
        dest = File.join(remote_path, "test_trigger.tar-ab")

        expect(Logger).to receive(:info).ordered
          .with("Storing '123.45.678.90:#{dest}'...")

        expect(connection).to receive(:upload!).ordered.with(src, dest)

        storage.send(:transfer!)
      end
    end # describe '#transfer!'

    describe "#remove!" do
      let(:connection) { double }
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join("my/path/test_trigger", timestamp) }
      let(:package) do
        double(
          Package, # loaded from YAML storage file
          trigger: "test_trigger",
          time: timestamp,
          filenames: ["test_trigger.tar-aa", "test_trigger.tar-ab"]
        )
      end

      before do
        Timecop.freeze
        storage.path = "my/path"
      end

      after { Timecop.return }

      it "removes the given package from the remote" do
        expect(Logger).to receive(:info).ordered
          .with("Removing backup package dated #{timestamp}...")

        expect(storage).to receive(:connection).ordered.and_yield(connection)

        target = File.join(remote_path, "test_trigger.tar-aa")
        expect(connection).to receive(:remove!).ordered.with(target)

        target = File.join(remote_path, "test_trigger.tar-ab")
        expect(connection).to receive(:remove!).ordered.with(target)

        expect(connection).to receive(:rmdir!).ordered.with(remote_path)

        storage.send(:remove!, package)
      end
    end # describe '#remove!'

    describe "#create_remote_path" do
      let(:connection)  { double }
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join("my/path/test_trigger", timestamp) }
      let(:sftp_response) { double(File::Stat, code: 11, message: nil) }
      let(:sftp_status_exception) { Net::SFTP::StatusException.new(sftp_response) }

      before do
        Timecop.freeze
        storage.package.time = timestamp
        storage.path = "my/path"
      end

      after { Timecop.return }

      context "while properly creating remote directories one by one" do
        it "should rescue any SFTP::StatusException and continue" do
          expect(connection).to receive(:mkdir!).ordered
            .with("my")
          expect(connection).to receive(:mkdir!).ordered
            .with("my/path").and_raise(sftp_status_exception)
          expect(connection).to receive(:mkdir!).ordered
            .with("my/path/test_trigger")
          expect(connection).to receive(:mkdir!).ordered
            .with("my/path/test_trigger/#{timestamp}")

          expect do
            storage.send(:create_remote_path, connection)
          end.not_to raise_error
        end
      end
    end # describe '#create_remote_path'
  end
end
