require "spec_helper"

module Backup
  describe Storage::AliyunOss do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:required_config) do
      proc do |oss|
        oss.access_key = "my_access_key"
        oss.secret_key = "my_secret_key"
        oss.bucket     = "my_bucket"
        oss.endpoint   = "my_endpoint"
      end
    end
    let(:storage) { Storage::AliyunOss.new(model, &required_config) }
    let(:s) { sequence "" }

    describe "#initialize" do
      it "provides default values" do
        # required
        expect(storage.bucket).to eq "my_bucket"
        expect(storage.access_key).to eq "my_access_key"
        expect(storage.secret_key).to eq "my_secret_key"
        expect(storage.endpoint).to eq "my_endpoint"

        # defaults
        expect(storage.storage_id).to be_nil
        expect(storage.keep).to be_nil
        expect(storage.path).to eq "backups"
      end

      it "requires access_key secret_key and bucket" do
        expect do
          Storage::AliyunOss.new(model)
        end.to raise_error { |err|
          expect(err.message).to match(/#access_key, #secret_key, #bucket, #endpoint are all required/)
        }
      end
    end

    it "#client" do
      ::Aliyun::OSS::Client.expects(:new).with(endpoint: 'my_endpoint', access_key_id: "my_access_key", access_key_secret: "my_secret_key")

      pre_config = required_config
      storage = Storage::AliyunOss.new(model) do |qiniu|
        pre_config.call(qiniu)
      end
      storage.instance_eval { client }
    end

    describe "#transfer!" do
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join("my/path/test_trigger", timestamp) }
      let(:uptoken) { "uptoken" }

      before do
        Timecop.freeze
        storage.package.time = timestamp
        storage.package.stubs(:filenames).returns(
          ["test_trigger.tar-aa", "test_trigger.tar-ab"]
        )
        storage.path = "my/path"
      end

      after { Timecop.return }

      it "transfers the package files" do
        src = File.join(Config.tmp_path, "test_trigger.tar-aa")
        dest = File.join(remote_path, "test_trigger.tar-aa")

        Logger.expects(:info).in_sequence(s).with("Storing '#{dest}'...")
        Aliyun::OSS::Bucket.any_instance.expects(:put_object).with(dest, file: src)

        src = File.join(Config.tmp_path, "test_trigger.tar-ab")
        dest = File.join(remote_path, "test_trigger.tar-ab")

        Logger.expects(:info).in_sequence(s).with("Storing '#{dest}'...")
        Aliyun::OSS::Bucket.any_instance.expects(:put_object).with(dest, file: src)

        storage.send(:transfer!)
      end
    end

    describe "#remove" do
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join("my/path/test_trigger", timestamp) }
      let(:uptoken) { "uptoken" }
      let(:package) do
        stub( # loaded from YAML storage file
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
        Logger.expects(:info).in_sequence(s).with("Removing backup package dated #{timestamp}...")

        dest = File.join(remote_path, "test_trigger.tar-aa")
        Aliyun::OSS::Bucket.any_instance.expects(:delete_object).with(dest)

        dest = File.join(remote_path, "test_trigger.tar-ab")
        Aliyun::OSS::Bucket.any_instance.expects(:delete_object).with(dest)

        storage.send(:remove!, package)
      end
    end
  end
end
