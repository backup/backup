require "spec_helper"

module Backup
  describe Storage::FTP do
    let(:model)   { Model.new(:test_trigger, "test label") }
    let(:storage) { Storage::FTP.new(model) }
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
        expect(storage.ip).to be_nil
        expect(storage.port).to be 21
        expect(storage.passive_mode).to be false
        expect(storage.timeout).to be nil
        expect(storage.path).to eq "backups"
      end

      it "configures the storage" do
        storage = Storage::FTP.new(model, :my_id) do |ftp|
          ftp.keep = 2
          ftp.username      = "my_username"
          ftp.password      = "my_password"
          ftp.ip            = "my_host"
          ftp.port          = 123
          ftp.passive_mode  = true
          ftp.timeout       = 10
          ftp.path          = "my/path"
        end

        expect(storage.storage_id).to eq "my_id"
        expect(storage.keep).to be 2
        expect(storage.username).to eq "my_username"
        expect(storage.password).to eq "my_password"
        expect(storage.ip).to eq "my_host"
        expect(storage.port).to be 123
        expect(storage.passive_mode).to be true
        expect(storage.timeout).to be 10
        expect(storage.path).to eq "my/path"
      end

      it "converts a tilde path to a relative path" do
        storage = Storage::FTP.new(model) do |scp|
          scp.path = "~/my/path"
        end
        expect(storage.path).to eq "my/path"
      end

      it "does not alter an absolute path" do
        storage = Storage::FTP.new(model) do |scp|
          scp.path = "/my/path"
        end
        expect(storage.path).to eq "/my/path"
      end
    end # describe '#initialize'

    describe "#connection" do
      let(:connection) { double }

      before do
        @ftp_port = Net::FTP::FTP_PORT
        storage.ip = "123.45.678.90"
        storage.username = "my_user"
        storage.password = "my_pass"
      end

      after do
        Net::FTP.send(:remove_const, :FTP_PORT)
        Net::FTP.send(:const_set, :FTP_PORT, @ftp_port)
      end

      it "yields a connection to the remote server" do
        expect(Net::FTP).to receive(:open).with(
          "123.45.678.90", "my_user", "my_pass"
        ).and_yield(connection)

        storage.send(:connection) do |ftp|
          expect(ftp).to be connection
        end
      end

      it "sets the FTP_PORT" do
        storage = Storage::FTP.new(model) do |ftp|
          ftp.port = 123
        end
        allow(Net::FTP).to receive(:open)

        storage.send(:connection)
        expect(Net::FTP::FTP_PORT).to be 123
      end

      # there's no way to really test this without making a connection,
      # since an error will be raised if no connection can be made.
      it "sets passive mode true if specified" do
        storage.passive_mode = true

        expect(Net::FTP).to receive(:open).with(
          "123.45.678.90", "my_user", "my_pass"
        ).and_yield(connection)

        expect(connection).to receive(:passive=).with(true)

        storage.send(:connection) {}
      end

      it "sets timeout if specified" do
        storage.timeout = 10

        expect(Net::FTP).to receive(:open).with(
          "123.45.678.90", "my_user", "my_pass"
        ).and_yield(connection)

        expect(connection).to receive(:open_timeout=).with(10)
        expect(connection).to receive(:read_timeout=).with(10)

        storage.send(:connection) {}
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

        expect(connection).to receive(:put).ordered.with(src, dest)

        src = File.join(Config.tmp_path, "test_trigger.tar-ab")
        dest = File.join(remote_path, "test_trigger.tar-ab")

        expect(Logger).to receive(:info).ordered
          .with("Storing '123.45.678.90:#{dest}'...")

        expect(connection).to receive(:put).ordered.with(src, dest)

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
        expect(connection).to receive(:delete).ordered.with(target)

        target = File.join(remote_path, "test_trigger.tar-ab")
        expect(connection).to receive(:delete).ordered.with(target)

        expect(connection).to receive(:rmdir).ordered.with(remote_path)

        storage.send(:remove!, package)
      end
    end # describe '#remove!'

    describe "#create_remote_path" do
      let(:connection)  { double }
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join("my/path/test_trigger", timestamp) }

      before do
        Timecop.freeze
        storage.package.time = timestamp
        storage.path = "my/path"
      end

      after { Timecop.return }

      context "while properly creating remote directories one by one" do
        it "should rescue any SFTP::StatusException and continue" do
          expect(connection).to receive(:mkdir).ordered
            .with("my")
          expect(connection).to receive(:mkdir).ordered
            .with("my/path").and_raise(Net::FTPPermError)
          expect(connection).to receive(:mkdir).ordered
            .with("my/path/test_trigger")
          expect(connection).to receive(:mkdir).ordered
            .with("my/path/test_trigger/#{timestamp}")

          expect do
            storage.send(:create_remote_path, connection)
          end.not_to raise_error
        end
      end
    end # describe '#create_remote_path'
  end
end
