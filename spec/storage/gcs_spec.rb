# encoding: utf-8

require File.expand_path("../../spec_helper.rb", __FILE__)

module Backup
  describe Storage::GCS do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:required_config) do
      proc do |gcs|
        gcs.google_storage_access_key_id      = "my_access_key_id"
        gcs.google_storage_secret_access_key  = "my_secret_access_key"
        gcs.bucket                            = "my_bucket"
      end
    end

    let(:storage) { Storage::GCS.new(model, &required_config) }
    let(:s) { sequence "" }

    it_behaves_like "a class that includes Config::Helpers"
    it_behaves_like "a subclass of Storage::Base"
    it_behaves_like "a storage that cycles"

    describe "#initialize" do
      it "provides default values" do
        # required
        expect(storage.bucket).to eq "my_bucket"
        # required unless using IAM profile
        expect(storage.google_storage_access_key_id).to eq "my_access_key_id"
        expect(storage.google_storage_secret_access_key).to eq "my_secret_access_key"

        # defaults
        expect(storage.path).to eq "backups"
        expect(storage.max_retries).to be 10
        expect(storage.retry_waitsec).to be 30
        expect(storage.fog_options).to be_nil
      end

      it "configures the storage" do
        storage = Storage::GCS.new(model, :my_id) do |gcs|
          gcs.keep                              = 2
          gcs.google_storage_access_key_id      = "my_access_key_id"
          gcs.google_storage_secret_access_key  = "my_secret_access_key"
          gcs.bucket                            = "my_bucket"
          gcs.path                              = "my/path"
          gcs.max_retries                       = 5
          gcs.retry_waitsec                     = 60
          gcs.fog_options                       = { my_key: "my_value" }
        end

        expect(storage.storage_id).to eq "my_id"
        expect(storage.keep).to be 2
        expect(storage.google_storage_access_key_id).to eq "my_access_key_id"
        expect(storage.google_storage_secret_access_key).to eq "my_secret_access_key"
        expect(storage.bucket).to eq "my_bucket"
        expect(storage.path).to eq "my/path"
        expect(storage.max_retries).to be 5
        expect(storage.retry_waitsec).to be 60
        expect(storage.fog_options).to eq my_key: "my_value"
      end

      it "configures the storage with values passed as frozen strings" do
        storage = Storage::GCS.new(model, :my_id) do |gcs|
          gcs.google_storage_access_key_id      = "my_access_key_id".freeze
          gcs.google_storage_secret_access_key  = "my_secret_access_key".freeze
          gcs.bucket                            = "my_bucket".freeze
          gcs.path                              = "my/path".freeze
        end

        expect(storage.storage_id).to eq "my_id"
        expect(storage.google_storage_access_key_id).to eq "my_access_key_id"
        expect(storage.google_storage_secret_access_key).to eq "my_secret_access_key"
        expect(storage.bucket).to eq "my_bucket"
        expect(storage.path).to eq "my/path"
      end

      it "requires bucket" do
        pre_config = required_config
        expect do
          Storage::GCS.new(model) do |gcs|
            pre_config.call(gcs)
            gcs.bucket = nil
          end
        end.to raise_error { |err|
          expect(err.message).to match(/are all required/)
        }
      end

      context "when using XML access keys" do
        it "requires google_storage_access_key_id" do
          pre_config = required_config
          expect do
            Storage::GCS.new(model) do |gcs|
              pre_config.call(gcs)
              gcs.google_storage_access_key_id = nil
            end
          end.to raise_error { |err|
            expect(err.message).to match(/are all required/)
          }
        end

        it "requires google_storage_secret_access_key" do
          pre_config = required_config
          expect do
            Storage::GCS.new(model) do |gcs|
              pre_config.call(gcs)
              gcs.google_storage_secret_access_key = nil
            end
          end.to raise_error { |err|
            expect(err.message).to match(/are all required/)
          }
        end
      end

      it "strips leading path separator" do
        pre_config = required_config
        storage = Storage::GCS.new(model) do |gcs|
          pre_config.call(gcs)
          gcs.path = "/this/path"
        end
        expect(storage.path).to eq "this/path"
      end
    end # describe '#initialize'

    describe "#cloud_io" do
      specify "when using GCS XML access keys" do
        CloudIO::GCS.expects(:new).once.with(
          google_storage_access_key_id: "my_access_key_id",
          google_storage_secret_access_key: "my_secret_access_key",
          bucket: "my_bucket",
          max_retries: 10,
          retry_waitsec: 30,
          fog_options: nil
        ).returns(:cloud_io)

        storage = Storage::GCS.new(model, &required_config)

        expect(storage.send(:cloud_io)).to eq :cloud_io
        expect(storage.send(:cloud_io)).to eq :cloud_io
      end
    end # describe '#cloud_io'

    describe "#transfer!" do
      let(:cloud_io) { mock }
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join("my/path/test_trigger", timestamp) }

      before do
        Timecop.freeze
        storage.package.time = timestamp
        storage.package.stubs(:filenames).returns(
          ["test_trigger.tar-aa", "test_trigger.tar-ab"]
        )
        storage.stubs(:cloud_io).returns(cloud_io)
        storage.bucket = "my_bucket"
        storage.path = "my/path"
      end

      after { Timecop.return }

      it "transfers the package files" do
        src = File.join(Config.tmp_path, "test_trigger.tar-aa")
        dest = File.join(remote_path, "test_trigger.tar-aa")

        Logger.expects(:info).in_sequence(s).with("Storing 'my_bucket/#{dest}'...")
        cloud_io.expects(:upload).in_sequence(s).with(src, dest)

        src = File.join(Config.tmp_path, "test_trigger.tar-ab")
        dest = File.join(remote_path, "test_trigger.tar-ab")

        Logger.expects(:info).in_sequence(s).with("Storing 'my_bucket/#{dest}'...")
        cloud_io.expects(:upload).in_sequence(s).with(src, dest)

        storage.send(:transfer!)
      end
    end # describe '#transfer!'

    describe "#remove!" do
      let(:cloud_io) { mock }
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join("my/path/test_trigger", timestamp) }
      let(:package) do
        stub( # loaded from YAML storage file
          trigger: "test_trigger",
          time: timestamp
        )
      end

      before do
        Timecop.freeze
        storage.stubs(:cloud_io).returns(cloud_io)
        storage.bucket = "my_bucket"
        storage.path = "my/path"
      end

      after { Timecop.return }

      it "removes the given package from the remote" do
        Logger.expects(:info).with("Removing backup package dated #{timestamp}...")

        objects = ["some objects"]
        cloud_io.expects(:objects).with(remote_path).returns(objects)
        cloud_io.expects(:delete).with(objects)

        storage.send(:remove!, package)
      end

      it "raises an error if remote package is missing" do
        objects = []
        cloud_io.expects(:objects).with(remote_path).returns(objects)
        cloud_io.expects(:delete).never

        expect do
          storage.send(:remove!, package)
        end.to raise_error(
          Storage::GCS::Error,
          "Storage::GCS::Error: Package at '#{remote_path}' not found"
        )
      end
    end # describe '#remove!'
  end
end
