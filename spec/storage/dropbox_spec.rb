require "spec_helper"

module Backup
  describe Storage::Dropbox do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:storage) { Storage::Dropbox.new(model) }
    let(:s) { sequence "" }

    it_behaves_like "a class that includes Config::Helpers"
    it_behaves_like "a subclass of Storage::Base"
    it_behaves_like "a storage that cycles"

    describe "#initialize" do
      it "provides default values" do
        expect(storage.storage_id).to be_nil
        expect(storage.keep).to be_nil
        expect(storage.api_key).to be_nil
        expect(storage.api_secret).to be_nil
        expect(storage.cache_path).to eq ".cache"
        expect(storage.chunk_size).to be 4
        expect(storage.max_retries).to be 10
        expect(storage.retry_waitsec).to be 30
        expect(storage.path).to eq "backups"
      end

      it "configures the storage" do
        storage = Storage::Dropbox.new(model, :my_id) do |db|
          db.keep           = 2
          db.api_key        = "my_api_key"
          db.api_secret     = "my_api_secret"
          db.cache_path     = ".my_cache"
          db.chunk_size     = 10
          db.max_retries    = 15
          db.retry_waitsec  = 45
          db.path           = "my/path"
        end

        expect(storage.storage_id).to eq "my_id"
        expect(storage.keep).to be 2
        expect(storage.api_key).to eq "my_api_key"
        expect(storage.api_secret).to eq "my_api_secret"
        expect(storage.cache_path).to eq ".my_cache"
        expect(storage.chunk_size).to eq 10
        expect(storage.max_retries).to eq 15
        expect(storage.retry_waitsec).to eq 45
        expect(storage.path).to eq "my/path"
      end

      it "strips leading path separator" do
        storage = Storage::Dropbox.new(model) do |s3|
          s3.path = "/this/path"
        end
        expect(storage.path).to eq "this/path"
      end
    end # describe '#initialize'

    describe "#connection" do
      let(:session) { double }
      let(:client)  { double }

      context "when a cached session exists" do
        before do
          allow(storage).to receive(:cached_session).and_return(session)
          expect(storage).to receive(:create_write_and_return_new_session!).never
          expect(DropboxClient).to receive(:new).once.with(session, :app_folder).and_return(client)
        end

        it "uses the cached session to create the client" do
          expect(storage.send(:connection)).to be(client)
        end

        it "returns an already existing client" do
          expect(storage.send(:connection)).to be(client)
          expect(storage.send(:connection)).to be(client)
        end
      end

      context "when a cached session does not exist" do
        before do
          allow(storage).to receive(:cached_session).and_return(false)
          expect(Logger).to receive(:info).with("Creating a new session!")
          expect(storage).to receive(:create_write_and_return_new_session!).and_return(session)
          expect(DropboxClient).to receive(:new).once.with(session, :app_folder).and_return(client)
        end

        it "creates a new session and returns the client" do
          expect(storage.send(:connection)).to be(client)
        end

        it "returns an already existing client" do
          expect(storage.send(:connection)).to be(client)
          expect(storage.send(:connection)).to be(client)
        end
      end

      context "when an error is raised creating a client for the session" do
        it "raises an error" do
          allow(storage).to receive(:cached_session).and_return(true)
          expect(DropboxClient).to receive(:new).and_raise("error")

          expect do
            storage.send(:connection)
          end.to raise_error(Storage::Dropbox::Error) { |err|
            expect(err.message).to eq(
              "Storage::Dropbox::Error: Authorization Failed\n" \
              "--- Wrapped Exception ---\n" \
              "RuntimeError: error"
            )
          }
        end
      end
    end # describe '#connection'

    describe "#cached_session" do
      let(:session) { double }
      let(:cached_file) { storage.send(:cached_file) }

      before do
        storage.api_key = "my_api_key"
        storage.api_secret = "my_api_secret"
      end

      it "returns the cached session if one exists" do
        expect(File).to receive(:exist?).with(cached_file).and_return(true)
        expect(File).to receive(:read).with(cached_file).and_return("yaml_data")
        expect(DropboxSession).to receive(:deserialize).with("yaml_data").and_return(session)
        expect(Backup::Logger).to receive(:info).with("Session data loaded from cache!")

        expect(storage.send(:cached_session)).to be(session)
      end

      it "returns false when no cached session file exists" do
        expect(File).to receive(:exist?).with(cached_file).and_return(false)
        expect(storage.send(:cached_session)).to be false
      end

      context "when errors occur loading the session" do
        it "logs a warning and return false" do
          expect(File).to receive(:exist?).with(cached_file).and_return(true)
          expect(File).to receive(:read).with(cached_file).and_return("yaml_data")
          expect(DropboxSession).to receive(:deserialize).with("yaml_data")
            .and_raise("error message")
          expect(Logger).to receive(:warn) do |err|
            expect(err).to be_an_instance_of(Storage::Dropbox::Error)
            expect(err.message).to match(
              "Could not read session data from cache.\n" \
              "  Cache data might be corrupt."
            )
            expect(err.message).to match("RuntimeError: error message")
          end

          expect do
            expect(storage.send(:cached_session)).to be false
          end.not_to raise_error
        end
      end
    end # describe '#cached_session'

    describe "#transfer!" do
      let(:connection) { double }
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join("my/path/test_trigger", timestamp) }
      let(:file) { double }
      let(:uploader) { double }

      before do
        Timecop.freeze
        storage.package.time = timestamp
        allow(storage).to receive(:connection).and_return(connection)
        allow(file).to receive(:stat).and_return(double(File::Stat, size: 6_291_456))
        allow(uploader).to receive(:total_size).and_return(6_291_456)
        allow(uploader).to receive(:offset).and_return(
          0, 2_097_152, 4_194_304, 6_291_456,
          0, 2_097_152, 4_194_304, 6_291_456
        )
        storage.path = "my/path"
        storage.chunk_size = 2
      end

      after { Timecop.return }

      it "transfers the package files" do
        allow(storage.package).to receive(:filenames).and_return(
          ["test_trigger.tar-aa", "test_trigger.tar-ab"]
        )

        # first file
        src = File.join(Config.tmp_path, "test_trigger.tar-aa")
        dest = File.join(remote_path, "test_trigger.tar-aa")

        expect(Logger).to receive(:info).ordered.with("Storing '#{dest}'...")
        expect(File).to receive(:open).ordered.with(src, "r").and_yield(file)
        expect(connection).to receive(:get_chunked_uploader).ordered
          .with(file, 6_291_456).and_return(uploader)
        expect(uploader).to receive(:upload).ordered.exactly(3).times.with(2_097_152)
        expect(uploader).to receive(:finish).ordered.with(dest)

        # second file
        src = File.join(Config.tmp_path, "test_trigger.tar-ab")
        dest = File.join(remote_path, "test_trigger.tar-ab")

        expect(Logger).to receive(:info).ordered.with("Storing '#{dest}'...")
        expect(File).to receive(:open).ordered.with(src, "r").and_yield(file)
        expect(connection).to receive(:get_chunked_uploader).ordered
          .with(file, 6_291_456).and_return(uploader)
        expect(uploader).to receive(:upload).ordered.exactly(3).times.with(2_097_152)
        expect(uploader).to receive(:finish).ordered.with(dest)

        storage.send(:transfer!)
      end

      it "retries on errors" do
        storage.max_retries = 1
        allow(storage.package).to receive(:filenames).and_return(["test_trigger.tar"])

        src = File.join(Config.tmp_path, "test_trigger.tar")
        dest = File.join(remote_path, "test_trigger.tar")

        @logger_calls = 0
        expect(Logger).to receive(:info).exactly(3).times do |arg|
          @logger_calls += 1
          case @logger_calls
          when 1
            expect(arg).to eq "Storing '#{dest}'..."
          when 2
            expect(arg).to be_an_instance_of Storage::Dropbox::Error
            expect(arg.message).to match(
              "Storage::Dropbox::Error: Retry #1 of 1."
            )
            expect(arg.message).to match("RuntimeError: chunk failed")
          when 3
            expect(arg).to be_an_instance_of Storage::Dropbox::Error
            expect(arg.message).to match(
              "Storage::Dropbox::Error: Retry #1 of 1."
            )
            expect(arg.message).to match("RuntimeError: finish failed")
          end
        end

        expect(File).to receive(:open).ordered.with(src, "r").and_yield(file)
        expect(connection).to receive(:get_chunked_uploader).ordered
          .with(file, 6_291_456).and_return(uploader)

        expect(uploader).to receive(:upload).ordered.and_raise("chunk failed")

        expect(storage).to receive(:sleep).ordered.with(30)

        expect(uploader).to receive(:upload).ordered.exactly(3).times.with(2_097_152)

        expect(uploader).to receive(:finish).ordered.with(dest).and_raise("finish failed")

        expect(storage).to receive(:sleep).ordered.with(30)

        expect(uploader).to receive(:finish).ordered.with(dest)

        storage.send(:transfer!)
      end

      it "fails when retries are exceeded" do
        storage.max_retries = 2
        allow(storage.package).to receive(:filenames).and_return(["test_trigger.tar"])

        src = File.join(Config.tmp_path, "test_trigger.tar")
        dest = File.join(remote_path, "test_trigger.tar")

        @logger_calls = 0
        expect(Logger).to receive(:info).exactly(3).times do |arg|
          @logger_calls += 1
          case @logger_calls
          when 1
            expect(arg).to eq "Storing '#{dest}'..."
          when 2
            expect(arg).to be_an_instance_of Storage::Dropbox::Error
            expect(arg.message).to match(
              "Storage::Dropbox::Error: Retry #1 of 2."
            )
            expect(arg.message).to match("RuntimeError: chunk failed")
          when 3
            expect(arg).to be_an_instance_of Storage::Dropbox::Error
            expect(arg.message).to match(
              "Storage::Dropbox::Error: Retry #2 of 2."
            )
            expect(arg.message).to match("RuntimeError: chunk failed again")
          end
        end

        expect(File).to receive(:open).ordered.with(src, "r").and_yield(file)
        expect(connection).to receive(:get_chunked_uploader).ordered
          .with(file, 6_291_456).and_return(uploader)

        expect(uploader).to receive(:upload).ordered.and_raise("chunk failed")

        expect(storage).to receive(:sleep).ordered.with(30)

        expect(uploader).to receive(:upload).ordered.and_raise("chunk failed again")

        expect(storage).to receive(:sleep).ordered.with(30)

        expect(uploader).to receive(:upload).ordered.and_raise("strike three")

        expect(uploader).to receive(:finish).never

        expect do
          storage.send(:transfer!)
        end.to raise_error(Storage::Dropbox::Error) { |err|
          expect(err.message).to match("Upload Failed!")
          expect(err.message).to match("RuntimeError: strike three")
        }
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
          time: timestamp
        )
      end

      before do
        Timecop.freeze
        allow(storage).to receive(:connection).and_return(connection)
        storage.path = "my/path"
      end

      after { Timecop.return }

      it "removes the given package from the remote" do
        expect(Logger).to receive(:info).ordered
          .with("Removing backup package dated #{timestamp}...")

        expect(connection).to receive(:file_delete).with(remote_path)

        storage.send(:remove!, package)
      end
    end # describe '#remove!'

    describe "#cached_file" do
      before do
        storage.api_key = "my_api_key"
        storage.api_secret = "my_api_secret"
      end

      context "with default root_path" do
        specify "using default cache_path" do
          expect(storage.send(:cached_file)).to eq(
            File.join(Config.root_path, ".cache", "my_api_keymy_api_secret")
          )
        end

        specify "using relative cache_path" do
          storage.cache_path = ".my_cache"
          expect(storage.send(:cached_file)).to eq(
            File.join(Config.root_path, ".my_cache", "my_api_keymy_api_secret")
          )
        end

        specify "using absolute cache_path" do
          storage.cache_path = "/my/.cache"
          expect(storage.send(:cached_file)).to eq(
            "/my/.cache/my_api_keymy_api_secret"
          )
        end
      end

      context "with custom root_path" do
        before do
          allow(File).to receive(:directory?).and_return(true)
          Config.send(:update, root_path: "/my_root")
        end

        specify "using default cache_path" do
          expect(storage.send(:cached_file)).to eq(
            "/my_root/.cache/my_api_keymy_api_secret"
          )
        end

        specify "using relative cache_path" do
          storage.cache_path = ".my_cache"
          expect(storage.send(:cached_file)).to eq(
            "/my_root/.my_cache/my_api_keymy_api_secret"
          )
        end

        specify "using absolute cache_path" do
          storage.cache_path = "/my/.cache"
          expect(storage.send(:cached_file)).to eq(
            "/my/.cache/my_api_keymy_api_secret"
          )
        end
      end
    end # describe '#cached_file'

    describe "#write_cache!" do
      let(:session) { double }
      let(:cached_file) { storage.send(:cached_file) }
      let(:file) { double }

      before do
        storage.api_key = "my_api_key"
        storage.api_secret = "my_api_secret"
        allow(session).to receive(:serialize).and_return("serialized_data")
      end

      it "should write a serialized session to file" do
        expect(FileUtils).to receive(:mkdir_p).with(File.dirname(cached_file))

        expect(File).to receive(:open).with(cached_file, "w").and_yield(file)
        expect(file).to receive(:write).with("serialized_data")

        storage.send(:write_cache!, session)
      end
    end # describe '#write_cache!'

    describe "#create_write_and_return_new_session!" do
      let(:session)   { double }
      let(:template)  { double }
      let(:cached_file) { storage.send(:cached_file) }

      before do
        storage.api_key = "my_api_key"
        storage.api_secret = "my_api_secret"

        expect(DropboxSession).to receive(:new).ordered
          .with("my_api_key", "my_api_secret").and_return(session)
        expect(session).to receive(:get_request_token).ordered
        expect(Template).to receive(:new).ordered.with(
          session: session, cached_file: cached_file
        ).and_return(template)
        expect(template).to receive(:render).ordered.with(
          "storage/dropbox/authorization_url.erb"
        )
        expect(Timeout).to receive(:timeout).ordered.with(180).and_yield
        expect(STDIN).to receive(:gets).ordered
      end

      context "when session is authenticated" do
        before do
          expect(session).to receive(:get_access_token).ordered
        end

        it "caches and returns the new session" do
          expect(template).to receive(:render).ordered.with(
            "storage/dropbox/authorized.erb"
          )
          expect(storage).to receive(:write_cache!).ordered.with(session)
          expect(template).to receive(:render).ordered.with(
            "storage/dropbox/cache_file_written.erb"
          )

          expect(storage.send(:create_write_and_return_new_session!)).to be(session)
        end
      end

      context "when session is not authenticated" do
        before do
          expect(session).to receive(:get_access_token).ordered.and_raise("error message")
        end

        it "raises an error" do
          expect(template).to receive(:render).with("storage/dropbox/authorized.erb").never
          expect(storage).to receive(:write_cache!).never
          expect(template).to receive(:render).with("storage/dropbox/cache_file_written.erb").never

          expect do
            storage.send(:create_write_and_return_new_session!)
          end.to raise_error(Storage::Dropbox::Error) { |err|
            expect(err.message).to match(
              "Could not create or authenticate a new session"
            )
            expect(err.message).to match("RuntimeError: error message")
          }
        end
      end
    end # describe '#create_write_and_return_new_session!' do
  end
end
