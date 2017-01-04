# encoding: utf-8
require File.expand_path("../../spec_helper.rb", __FILE__)
require "backup/cloud_io/gcs"

module Backup
  describe CloudIO::GCS do
    let(:connection) { mock }

    describe "#upload" do
      let(:cloud_io) { CloudIO::GCS.new(bucket: "my_bucket") }

      context "when src file size is ok" do
        before do
          File.expects(:size).with("/src/file")
            .returns(described_class::MAX_FILE_SIZE)
        end

        it "uploads using put_object" do
          cloud_io.expects(:put_object).with("/src/file", "dest/file")

          cloud_io.upload("/src/file", "dest/file")
        end
      end

      context "when src file is too large" do
        before do
          File.expects(:size).with("/src/file")
            .returns(described_class::MAX_FILE_SIZE + 1)
        end

        it "raises an error" do
          cloud_io.expects(:put_object).never

          expect do
            cloud_io.upload("/src/file", "dest/file")
          end.to raise_error(CloudIO::FileSizeError)
        end
      end
    end # describe '#upload'

    describe "#objects" do
      let(:cloud_io) do
        CloudIO::GCS.new(
          bucket: "my_bucket",
          max_retries: 1,
          retry_waitsec: 0
        )
      end

      before do
        cloud_io.stubs(:connection).returns(connection)
      end

      it "ensures prefix ends with /" do
        connection.expects(:get_bucket)
          .with("my_bucket", "prefix" => "foo/bar/")
          .returns(stub(body: { "Contents" => [] }))
        expect(cloud_io.objects("foo/bar")).to eq []
      end

      it "returns an empty array when no objects are found" do
        connection.expects(:get_bucket)
          .with("my_bucket", "prefix" => "foo/bar/")
          .returns(stub(body: { "Contents" => [] }))
        expect(cloud_io.objects("foo/bar/")).to eq []
      end

      context "when returned objects are not truncated" do
        let(:resp_body) do
          { "IsTruncated" => false,
            "Contents" => Array.new(10) do |n|
              { "Key" => "key_#{n}",
                "ETag" => "etag_#{n}",
                "StorageClass" => "STANDARD" }
            end }
        end

        it "returns all objects" do
          cloud_io.expects(:with_retries)
            .with("GET 'my_bucket/foo/bar/*'").yields
          connection.expects(:get_bucket)
            .with("my_bucket", "prefix" => "foo/bar/")
            .returns(stub(body: resp_body))

          objects = cloud_io.objects("foo/bar/")
          expect(objects.count).to be 10
          objects.each_with_index do |object, n|
            expect(object.key).to eq("key_#{n}")
            expect(object.etag).to eq("etag_#{n}")
            expect(object.storage_class).to eq("STANDARD")
          end
        end
      end

      context "when returned objects are truncated" do
        let(:resp_body_a) do
          { "IsTruncated" => true,
            "Contents" => (0..6).map do |n|
              { "Key" => "key_#{n}",
                "ETag" => "etag_#{n}",
                "StorageClass" => "STANDARD" }
            end }
        end
        let(:resp_body_b) do
          { "IsTruncated" => false,
            "Contents" => (7..9).map do |n|
              { "Key" => "key_#{n}",
                "ETag" => "etag_#{n}",
                "StorageClass" => "STANDARD" }
            end }
        end

        it "returns all objects" do
          cloud_io.expects(:with_retries).twice
            .with("GET 'my_bucket/foo/bar/*'").yields
          connection.expects(:get_bucket)
            .with("my_bucket", "prefix" => "foo/bar/")
            .returns(stub(body: resp_body_a))
          connection.expects(:get_bucket)
            .with("my_bucket", "prefix" => "foo/bar/", "marker" => "key_6")
            .returns(stub(body: resp_body_b))

          objects = cloud_io.objects("foo/bar/")
          expect(objects.count).to be 10
          objects.each_with_index do |object, n|
            expect(object.key).to eq("key_#{n}")
            expect(object.etag).to eq("etag_#{n}")
            expect(object.storage_class).to eq("STANDARD")
          end
        end

        it "retries on errors" do
          connection.expects(:get_bucket).twice
            .with("my_bucket", "prefix" => "foo/bar/")
            .raises("error").then
            .returns(stub(body: resp_body_a))
          connection.expects(:get_bucket).twice
            .with("my_bucket", "prefix" => "foo/bar/", "marker" => "key_6")
            .raises("error").then
            .returns(stub(body: resp_body_b))

          objects = cloud_io.objects("foo/bar/")
          expect(objects.count).to be 10
          objects.each_with_index do |object, n|
            expect(object.key).to eq("key_#{n}")
            expect(object.etag).to eq("etag_#{n}")
            expect(object.storage_class).to eq("STANDARD")
          end
        end
      end
    end # describe '#objects'

    #
    describe "#delete" do
      let(:cloud_io) do
        CloudIO::GCS.new(
          bucket: "my_bucket",
          max_retries: 1,
          retry_waitsec: 0
        )
      end
      let(:resp_ok) { stub(body: {}) }

      before do
        cloud_io.stubs(:connection).returns(connection)
      end

      it "accepts a single Object" do
        object = described_class::Object.new(:foo, "Key" => "obj_key")
        cloud_io.expects(:with_retries).with("DELETE object").yields
        connection.expects(:delete).with(
          "my_bucket", "obj_key"
        ).returns(resp_ok)
        cloud_io.delete(object)
      end

      it "accepts multiple Objects" do
        object_a = described_class::Object.new(:foo, "Key" => "obj_key_a")
        object_b = described_class::Object.new(:foo, "Key" => "obj_key_b")
        cloud_io.expects(:with_retries).with("DELETE object").twice.yields
        connection.expects(:delete).with(
          "my_bucket", anything
        ).twice.returns(resp_ok)

        objects = [object_a, object_b]
        expect do
          cloud_io.delete(objects)
        end.not_to change { objects }
      end

      it "accepts a single key" do
        cloud_io.expects(:with_retries).with("DELETE object").yields
        connection.expects(:delete).with(
          "my_bucket", "obj_key"
        ).returns(resp_ok)
        cloud_io.delete("obj_key")
      end

      it "accepts multiple keys" do
        cloud_io.expects(:with_retries).with("DELETE object").twice.yields
        connection.expects(:delete).with(
          "my_bucket", anything
        ).twice.returns(resp_ok)

        objects = ["obj_key_a", "obj_key_b"]
        expect do
          cloud_io.delete(objects)
        end.not_to change { objects }
      end

      it "does nothing if empty array passed" do
        connection.expects(:delete).never
        cloud_io.delete([])
      end

      it "retries on raised errors" do
        connection.expects(:delete).twice
          .with("my_bucket", "obj_key")
          .raises("error").then.returns(resp_ok)
        cloud_io.delete("obj_key")
      end

      it "fails after retries exceeded" do
        connection.expects(:delete).twice
          .with("my_bucket", "obj_key")
          .raises("error message")

        expect do
          cloud_io.delete("obj_key")
        end.to raise_error(CloudIO::Error) { |err|
          expect(err.message).to eq(
            "CloudIO::Error: Max Retries (1) Exceeded!\n" \
            "  Operation: DELETE object\n" \
            "  Be sure to check the log messages for each retry attempt.\n" \
            "--- Wrapped Exception ---\n" \
            "CloudIO::GCS::Error: The server returned the following:\n" \
            "  error message"
          )
        }
        expect(Logger.messages.map(&:lines).join("\n")).to eq(
          "CloudIO::Error: Retry #1 of 1\n" \
          "  Operation: DELETE object\n" \
          "--- Wrapped Exception ---\n" \
          "CloudIO::GCS::Error: The server returned the following:\n" \
          "  error message"
        )
      end
    end # describe '#delete'

    describe "#connection" do
      specify "using GCS XML access keys" do
        Fog::Storage.expects(:new).once.with(
          provider: "Google",
          google_storage_access_key_id: "my_access_key_id",
          google_storage_secret_access_key: "my_secret_access_key"
        ).returns(connection)

        cloud_io = CloudIO::GCS.new(
          google_storage_access_key_id: "my_access_key_id",
          google_storage_secret_access_key: "my_secret_access_key"
        )

        expect(cloud_io.send(:connection)).to be connection
        expect(cloud_io.send(:connection)).to be connection
      end

      it "passes along fog_options" do
        Fog::Storage.expects(:new).with(provider: "AWS",
                                          region: nil,
                                          aws_access_key_id: "my_key",
                                          aws_secret_access_key: "my_secret",
                                          connection_options: { opt_key: "opt_value" },
                                          my_key: "my_value").returns(stub(:sync_clock))
        CloudIO::S3.new(
          access_key_id: "my_key",
          secret_access_key: "my_secret",
          fog_options: {
            connection_options: { opt_key: "opt_value" },
            my_key: "my_value"
          }
        ).send(:connection)
      end
    end # describe '#connection'

    describe "#put_object" do
      let(:cloud_io) do
        CloudIO::GCS.new(
          bucket: "my_bucket",
          max_retries: 1,
          retry_waitsec: 0
        )
      end
      let(:file) { mock }

      before do
        cloud_io.stubs(:connection).returns(connection)
        md5_file = mock
        Digest::MD5.expects(:file).with("/src/file").returns(md5_file)
        md5_file.expects(:digest).returns(:md5_digest)
        Base64.expects(:encode64).with(:md5_digest).returns("encoded_digest\n")
      end

      it "calls put_object with Content-MD5 header" do
        File.expects(:open).with("/src/file", "r").yields(file)
        connection.expects(:put_object)
          .with("my_bucket", "dest/file", file, "Content-MD5" => "encoded_digest")
        cloud_io.send(:put_object, "/src/file", "dest/file")
      end

      it "fails after retries" do
        File.expects(:open).twice.with("/src/file", "r").yields(file)
        connection.expects(:put_object).twice
          .with("my_bucket", "dest/file", file, "Content-MD5" => "encoded_digest")
          .raises("error1").then.raises("error2")

        expect do
          cloud_io.send(:put_object, "/src/file", "dest/file")
        end.to raise_error(CloudIO::Error) { |err|
          expect(err.message).to eq(
            "CloudIO::Error: Max Retries (1) Exceeded!\n" \
            "  Operation: PUT 'my_bucket/dest/file'\n" \
            "  Be sure to check the log messages for each retry attempt.\n" \
            "--- Wrapped Exception ---\n" \
            "CloudIO::GCS::Error: The server returned the following:\n" \
            "  error2"
          )
        }
        expect(Logger.messages.map(&:lines).join("\n")).to eq(
          "CloudIO::Error: Retry #1 of 1\n" \
          "  Operation: PUT 'my_bucket/dest/file'\n" \
          "--- Wrapped Exception ---\n" \
          "CloudIO::GCS::Error: The server returned the following:\n" \
          "  error1"
        )
      end
    end # describe '#put_object'

    describe "Object" do
      let(:cloud_io) { CloudIO::S3.new }
      let(:obj_data) do
        { "Key" => "obj_key", "ETag" => "obj_etag", "StorageClass" => "STANDARD" }
      end
      let(:object) { CloudIO::GCS::Object.new(cloud_io, obj_data) }

      describe "#initialize" do
        it "creates Object from data" do
          expect(object.key).to eq "obj_key"
          expect(object.etag).to eq "obj_etag"
          expect(object.storage_class).to eq "STANDARD"
        end
      end
    end # describe 'Object'
  end
end
