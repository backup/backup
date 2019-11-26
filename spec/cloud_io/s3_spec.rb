require "spec_helper"
require "backup/cloud_io/s3"

module Backup
  describe CloudIO::S3 do
    let(:connection) { double }

    describe "#upload" do
      context "with multipart support" do
        let(:cloud_io) { CloudIO::S3.new(bucket: "my_bucket", chunk_size: 5) }
        let(:parts) { double }

        context "when src file is larger than chunk_size" do
          before do
            expect(File).to receive(:size).with("/src/file").and_return(10 * 1024**2)
          end

          it "uploads using multipart" do
            expect(cloud_io).to receive(:initiate_multipart).with("dest/file").and_return(1234)
            expect(cloud_io).to receive(:upload_parts).with(
              "/src/file", "dest/file", 1234, 5 * 1024**2, 10 * 1024**2
            ).and_return(parts)
            expect(cloud_io).to receive(:complete_multipart).with("dest/file", 1234, parts)
            expect(cloud_io).to receive(:put_object).never

            cloud_io.upload("/src/file", "dest/file")
          end
        end

        context "when src file is not larger than chunk_size" do
          before do
            expect(File).to receive(:size).with("/src/file").and_return(5 * 1024**2)
          end

          it "uploads without multipart" do
            expect(cloud_io).to receive(:put_object).with("/src/file", "dest/file")
            expect(cloud_io).to receive(:initiate_multipart).never

            cloud_io.upload("/src/file", "dest/file")
          end
        end

        context "when chunk_size is too small for the src file" do
          before do
            expect(File).to receive(:size).with("/src/file").and_return((50_000 * 1024**2) + 1)
          end

          it "warns and adjusts the chunk_size" do
            expect(cloud_io).to receive(:initiate_multipart).with("dest/file").and_return(1234)
            expect(cloud_io).to receive(:upload_parts).with(
              "/src/file", "dest/file", 1234, 6 * 1024**2, (50_000 * 1024**2) + 1
            ).and_return(parts)
            expect(cloud_io).to receive(:complete_multipart).with("dest/file", 1234, parts)
            expect(cloud_io).to receive(:put_object).never

            expect(Logger).to receive(:warn) do |err|
              expect(err.message).to include(
                "#chunk_size of 5 MiB has been adjusted\n  to 6 MiB"
              )
            end

            cloud_io.upload("/src/file", "dest/file")
          end
        end

        context "when src file is too large" do
          before do
            expect(File).to receive(:size).with("/src/file")
              .and_return(described_class::MAX_MULTIPART_SIZE + 1)
          end

          it "raises an error" do
            expect(cloud_io).to receive(:initiate_multipart).never
            expect(cloud_io).to receive(:put_object).never

            expect do
              cloud_io.upload("/src/file", "dest/file")
            end.to raise_error(CloudIO::FileSizeError)
          end
        end
      end # context 'with multipart support'

      context "without multipart support" do
        let(:cloud_io) { CloudIO::S3.new(bucket: "my_bucket", chunk_size: 0) }

        before do
          expect(cloud_io).to receive(:initiate_multipart).never
        end

        context "when src file size is ok" do
          before do
            expect(File).to receive(:size).with("/src/file")
              .and_return(described_class::MAX_FILE_SIZE)
          end

          it "uploads using put_object" do
            expect(cloud_io).to receive(:put_object).with("/src/file", "dest/file")

            cloud_io.upload("/src/file", "dest/file")
          end
        end

        context "when src file is too large" do
          before do
            expect(File).to receive(:size).with("/src/file")
              .and_return(described_class::MAX_FILE_SIZE + 1)
          end

          it "raises an error" do
            expect(cloud_io).to receive(:put_object).never

            expect do
              cloud_io.upload("/src/file", "dest/file")
            end.to raise_error(CloudIO::FileSizeError)
          end
        end
      end # context 'without multipart support'
    end # describe '#upload'

    describe "#objects" do
      let(:cloud_io) do
        CloudIO::S3.new(
          bucket: "my_bucket",
          max_retries: 1,
          retry_waitsec: 0
        )
      end

      before do
        allow(cloud_io).to receive(:connection).and_return(connection)
      end

      it "ensures prefix ends with /" do
        expect(connection).to receive(:get_bucket)
          .with("my_bucket", "prefix" => "foo/bar/")
          .and_return(double("response", body: { "Contents" => [] }))
        expect(cloud_io.objects("foo/bar")).to eq []
      end

      it "returns an empty array when no objects are found" do
        expect(connection).to receive(:get_bucket)
          .with("my_bucket", "prefix" => "foo/bar/")
          .and_return(double("response", body: { "Contents" => [] }))
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
          expect(cloud_io).to receive(:with_retries)
            .with("GET 'my_bucket/foo/bar/*'").and_yield
          expect(connection).to receive(:get_bucket)
            .with("my_bucket", "prefix" => "foo/bar/")
            .and_return(double("response", body: resp_body))

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
          expect(cloud_io).to receive(:with_retries).twice
            .with("GET 'my_bucket/foo/bar/*'").and_yield
          expect(connection).to receive(:get_bucket)
            .with("my_bucket", "prefix" => "foo/bar/")
            .and_return(double("response", body: resp_body_a))
          expect(connection).to receive(:get_bucket)
            .with("my_bucket", "prefix" => "foo/bar/", "marker" => "key_6")
            .and_return(double("response", body: resp_body_b))

          objects = cloud_io.objects("foo/bar/")
          expect(objects.count).to be 10
          objects.each_with_index do |object, n|
            expect(object.key).to eq("key_#{n}")
            expect(object.etag).to eq("etag_#{n}")
            expect(object.storage_class).to eq("STANDARD")
          end
        end

        it "retries on errors" do
          expect(connection).to receive(:get_bucket).once
            .with("my_bucket", "prefix" => "foo/bar/")
            .and_raise("error")
          expect(connection).to receive(:get_bucket).once
            .with("my_bucket", "prefix" => "foo/bar/")
            .and_return(double("response", body: resp_body_a))
          expect(connection).to receive(:get_bucket).once
            .with("my_bucket", "prefix" => "foo/bar/", "marker" => "key_6")
            .and_raise("error")
          expect(connection).to receive(:get_bucket).once
            .with("my_bucket", "prefix" => "foo/bar/", "marker" => "key_6")
            .and_return(double("response", body: resp_body_b))

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

    describe "#head_object" do
      let(:cloud_io) do
        CloudIO::S3.new(
          bucket: "my_bucket",
          max_retries: 1,
          retry_waitsec: 0
        )
      end

      before do
        allow(cloud_io).to receive(:connection).and_return(connection)
      end

      it "returns head_object response with retries" do
        object = double("response", key: "obj_key")
        expect(connection).to receive(:head_object).once
          .with("my_bucket", "obj_key")
          .and_raise("error")
        expect(connection).to receive(:head_object).once
          .with("my_bucket", "obj_key")
          .and_return(:response)
        expect(cloud_io.head_object(object)).to eq :response
      end
    end # describe '#head_object'

    describe "#delete" do
      let(:cloud_io) do
        CloudIO::S3.new(
          bucket: "my_bucket",
          max_retries: 1,
          retry_waitsec: 0
        )
      end
      let(:resp_ok) { double("response", body: { "DeleteResult" => [] }) }
      let(:resp_bad) do
        double(
          "response",
          body: {
            "DeleteResult" => [
              { "Error" => {
                "Key" => "obj_key",
                "Code" => "InternalError",
                "Message" => "We encountered an internal error. Please try again."
              } }
            ]
          }
        )
      end

      before do
        allow(cloud_io).to receive(:connection).and_return(connection)
      end

      it "accepts a single Object" do
        object = described_class::Object.new(:foo, "Key" => "obj_key")
        expect(cloud_io).to receive(:with_retries).with("DELETE Multiple Objects").and_yield
        expect(connection).to receive(:delete_multiple_objects).with(
          "my_bucket", ["obj_key"], quiet: true
        ).and_return(resp_ok)
        cloud_io.delete(object)
      end

      it "accepts multiple Objects" do
        object_a = described_class::Object.new(:foo, "Key" => "obj_key_a")
        object_b = described_class::Object.new(:foo, "Key" => "obj_key_b")
        expect(cloud_io).to receive(:with_retries).with("DELETE Multiple Objects").and_yield
        expect(connection).to receive(:delete_multiple_objects).with(
          "my_bucket", ["obj_key_a", "obj_key_b"], quiet: true
        ).and_return(resp_ok)

        objects = [object_a, object_b]
        expect { cloud_io.delete(objects) }.not_to change { objects }
      end

      it "accepts a single key" do
        expect(cloud_io).to receive(:with_retries).with("DELETE Multiple Objects").and_yield
        expect(connection).to receive(:delete_multiple_objects).with(
          "my_bucket", ["obj_key"], quiet: true
        ).and_return(resp_ok)
        cloud_io.delete("obj_key")
      end

      it "accepts multiple keys" do
        expect(cloud_io).to receive(:with_retries).with("DELETE Multiple Objects").and_yield
        expect(connection).to receive(:delete_multiple_objects).with(
          "my_bucket", ["obj_key_a", "obj_key_b"], quiet: true
        ).and_return(resp_ok)

        objects = ["obj_key_a", "obj_key_b"]
        expect { cloud_io.delete(objects) }.not_to change { objects }
      end

      it "does nothing if empty array passed" do
        expect(connection).to receive(:delete_multiple_objects).never
        cloud_io.delete([])
      end

      context "with more than 1000 objects" do
        let(:keys_1k) { Array.new(1000) { "key" } }
        let(:keys_10) { Array.new(10) { "key" } }
        let(:keys_all) { keys_1k + keys_10 }

        before do
          expect(cloud_io).to receive(:with_retries).twice.with("DELETE Multiple Objects").and_yield
        end

        it "deletes 1000 objects per request" do
          expect(connection).to receive(:delete_multiple_objects).with(
            "my_bucket", keys_1k, quiet: true
          ).and_return(resp_ok)
          expect(connection).to receive(:delete_multiple_objects).with(
            "my_bucket", keys_10, quiet: true
          ).and_return(resp_ok)

          expect { cloud_io.delete(keys_all) }.not_to change { keys_all }
        end

        it "prevents mutation of options to delete_multiple_objects" do
          expect(connection).to receive(:delete_multiple_objects) do |bucket, keys, opts|
            bucket == "my_bucket" && keys == keys_1k && opts.delete(:quiet)
          end.and_return(resp_ok)
          expect(connection).to receive(:delete_multiple_objects).with(
            "my_bucket", keys_10, quiet: true
          ).and_return(resp_ok)

          expect { cloud_io.delete(keys_all) }.not_to change { keys_all }
        end
      end

      it "retries on raised errors" do
        expect(connection).to receive(:delete_multiple_objects).once
          .with("my_bucket", ["obj_key"], quiet: true)
          .and_raise("error")
        expect(connection).to receive(:delete_multiple_objects).once
          .with("my_bucket", ["obj_key"], quiet: true)
          .and_return(resp_ok)
        cloud_io.delete("obj_key")
      end

      it "retries on returned errors" do
        expect(connection).to receive(:delete_multiple_objects).twice
          .with("my_bucket", ["obj_key"], quiet: true)
          .and_return(resp_bad, resp_ok)
        cloud_io.delete("obj_key")
      end

      it "fails after retries exceeded" do
        expect(connection).to receive(:delete_multiple_objects).once
          .with("my_bucket", ["obj_key"], quiet: true)
          .and_raise("error message")
        expect(connection).to receive(:delete_multiple_objects).once
          .with("my_bucket", ["obj_key"], quiet: true)
          .and_return(resp_bad)

        expect do
          cloud_io.delete("obj_key")
        end.to raise_error CloudIO::Error, "CloudIO::Error: Max Retries (1) Exceeded!\n" \
          "  Operation: DELETE Multiple Objects\n" \
          "  Be sure to check the log messages for each retry attempt.\n" \
          "--- Wrapped Exception ---\n" \
          "CloudIO::S3::Error: The server returned the following:\n" \
          "  Failed to delete: obj_key\n" \
          "  Reason: InternalError: We encountered an internal error. " \
            "Please try again."
        expect(Logger.messages.map(&:lines).join("\n")).to eq(
          "CloudIO::Error: Retry #1 of 1\n" \
          "  Operation: DELETE Multiple Objects\n" \
          "--- Wrapped Exception ---\n" \
          "RuntimeError: error message"
        )
      end
    end # describe '#delete'

    describe "#connection" do
      specify "using AWS access keys" do
        expect(Fog::Storage).to receive(:new).once.with(
          provider: "AWS",
          aws_access_key_id: "my_access_key_id",
          aws_secret_access_key: "my_secret_access_key",
          region: "my_region"
        ).and_return(connection)
        expect(connection).to receive(:sync_clock).once

        cloud_io = CloudIO::S3.new(
          access_key_id: "my_access_key_id",
          secret_access_key: "my_secret_access_key",
          region: "my_region"
        )

        expect(cloud_io.send(:connection)).to be connection
        expect(cloud_io.send(:connection)).to be connection
      end

      specify "using AWS IAM profile" do
        expect(Fog::Storage).to receive(:new).once.with(
          provider: "AWS",
          use_iam_profile: true,
          region: "my_region"
        ).and_return(connection)
        expect(connection).to receive(:sync_clock).once

        cloud_io = CloudIO::S3.new(
          use_iam_profile: true,
          region: "my_region"
        )

        expect(cloud_io.send(:connection)).to be connection
        expect(cloud_io.send(:connection)).to be connection
      end

      it "passes along fog_options" do
        expect(Fog::Storage).to receive(:new).with(provider: "AWS",
                                                   region: nil,
                                                   aws_access_key_id: "my_key",
                                                   aws_secret_access_key: "my_secret",
                                                   connection_options: { opt_key: "opt_value" },
                                                   my_key: "my_value").and_return(double("response", sync_clock: nil))
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
        CloudIO::S3.new(
          bucket: "my_bucket",
          max_retries: 1,
          retry_waitsec: 0
        )
      end
      let(:file) { double }

      before do
        allow(cloud_io).to receive(:connection).and_return(connection)
        md5_file = double
        expect(Digest::MD5).to receive(:file).with("/src/file").and_return(md5_file)
        expect(md5_file).to receive(:digest).and_return(:md5_digest)
        expect(Base64).to receive(:encode64).with(:md5_digest).and_return("encoded_digest\n")
      end

      it "calls put_object with Content-MD5 header" do
        expect(File).to receive(:open).with("/src/file", "r").and_yield(file)
        expect(connection).to receive(:put_object)
          .with("my_bucket", "dest/file", file, "Content-MD5" => "encoded_digest")
        cloud_io.send(:put_object, "/src/file", "dest/file")
      end

      it "fails after retries" do
        expect(File).to receive(:open).twice.with("/src/file", "r").and_yield(file)
        expect(connection).to receive(:put_object).once
          .with("my_bucket", "dest/file", file, "Content-MD5" => "encoded_digest")
          .and_raise("error1")
        expect(connection).to receive(:put_object).once
          .with("my_bucket", "dest/file", file, "Content-MD5" => "encoded_digest")
          .and_raise("error2")

        expect do
          cloud_io.send(:put_object, "/src/file", "dest/file")
        end.to raise_error CloudIO::Error, "CloudIO::Error: Max Retries (1) Exceeded!\n" \
          "  Operation: PUT 'my_bucket/dest/file'\n" \
          "  Be sure to check the log messages for each retry attempt.\n" \
          "--- Wrapped Exception ---\n" \
          "RuntimeError: error2"
        expect(Logger.messages.map(&:lines).join("\n")).to eq(
          "CloudIO::Error: Retry #1 of 1\n" \
          "  Operation: PUT 'my_bucket/dest/file'\n" \
          "--- Wrapped Exception ---\n" \
          "RuntimeError: error1"
        )
      end

      context "with #encryption and #storage_class set" do
        let(:cloud_io) do
          CloudIO::S3.new(
            bucket: "my_bucket",
            encryption: :aes256,
            storage_class: :reduced_redundancy,
            max_retries: 1,
            retry_waitsec: 0
          )
        end

        it "sets headers for encryption and storage_class" do
          expect(File).to receive(:open).with("/src/file", "r").and_yield(file)
          expect(connection).to receive(:put_object).with(
            "my_bucket", "dest/file", file,
            "Content-MD5" => "encoded_digest",
              "x-amz-server-side-encryption" => "AES256",
              "x-amz-storage-class" => "REDUCED_REDUNDANCY"
          )
          cloud_io.send(:put_object, "/src/file", "dest/file")
        end
      end
    end # describe '#put_object'

    describe "#initiate_multipart" do
      let(:cloud_io) do
        CloudIO::S3.new(
          bucket: "my_bucket",
          max_retries: 1,
          retry_waitsec: 0
        )
      end
      let(:response) { double("response", body: { "UploadId" => 1234 }) }

      before do
        allow(cloud_io).to receive(:connection).and_return(connection)
        expect(Logger).to receive(:info).with("  Initiate Multipart 'my_bucket/dest/file'")
      end

      it "initiates multipart upload with retries" do
        expect(cloud_io).to receive(:with_retries)
          .with("POST 'my_bucket/dest/file' (Initiate)").and_yield
        expect(connection).to receive(:initiate_multipart_upload)
          .with("my_bucket", "dest/file", {}).and_return(response)

        expect(cloud_io.send(:initiate_multipart, "dest/file")).to be 1234
      end

      context "with #encryption and #storage_class set" do
        let(:cloud_io) do
          CloudIO::S3.new(
            bucket: "my_bucket",
            encryption: :aes256,
            storage_class: :reduced_redundancy,
            max_retries: 1,
            retry_waitsec: 0
          )
        end

        it "sets headers for encryption and storage_class" do
          expect(connection).to receive(:initiate_multipart_upload).with(
            "my_bucket", "dest/file",
            "x-amz-server-side-encryption" => "AES256",
              "x-amz-storage-class" => "REDUCED_REDUNDANCY"
          ).and_return(response)
          expect(cloud_io.send(:initiate_multipart, "dest/file")).to be 1234
        end
      end
    end # describe '#initiate_multipart'

    describe "#upload_parts" do
      let(:cloud_io) do
        CloudIO::S3.new(
          bucket: "my_bucket",
          max_retries: 1,
          retry_waitsec: 0
        )
      end
      let(:chunk_bytes) { 1024**2 * 5 }
      let(:file_size) { chunk_bytes + 250 }
      let(:chunk_a) { "a" * chunk_bytes }
      let(:encoded_digest_a) { "ebKBBg0ze5srhMzzkK3PdA==" }
      let(:chunk_a_resp) { double("response", headers: { "ETag" => "chunk_a_etag" }) }
      let(:chunk_b) { "b" * 250 }
      let(:encoded_digest_b) { "OCttLDka1ocamHgkHvZMyQ==" }
      let(:chunk_b_resp) { double("response", headers: { "ETag" => "chunk_b_etag" }) }
      let(:file) { StringIO.new(chunk_a + chunk_b) }

      before do
        allow(cloud_io).to receive(:connection).and_return(connection)
      end

      it "uploads chunks with Content-MD5" do
        expect(File).to receive(:open).with("/src/file", "r").and_yield(file)
        allow(StringIO).to receive(:new).with(chunk_a).and_return(:stringio_a)
        allow(StringIO).to receive(:new).with(chunk_b).and_return(:stringio_b)

        expect(cloud_io).to receive(:with_retries).with(
          "PUT 'my_bucket/dest/file' Part #1"
        ).and_yield

        expect(connection).to receive(:upload_part).with(
          "my_bucket", "dest/file", 1234, 1, :stringio_a,
          "Content-MD5" => encoded_digest_a
        ).and_return(chunk_a_resp)

        expect(cloud_io).to receive(:with_retries).with(
          "PUT 'my_bucket/dest/file' Part #2"
        ).and_yield

        expect(connection).to receive(:upload_part).with(
          "my_bucket", "dest/file", 1234, 2, :stringio_b,
          "Content-MD5" => encoded_digest_b
        ).and_return(chunk_b_resp)

        expect(
          cloud_io.send(:upload_parts,
            "/src/file", "dest/file", 1234, chunk_bytes, file_size)
        ).to eq ["chunk_a_etag", "chunk_b_etag"]

        expect(Logger.messages.map(&:lines).join("\n")).to eq(
          "  Uploading 2 Parts...\n" \
          "  ...90% Complete..."
        )
      end

      it "logs progress" do
        chunk_bytes = 1024**2 * 1
        file_size = chunk_bytes * 100
        file = StringIO.new("x" * file_size)
        expect(File).to receive(:open).with("/src/file", "r").and_yield(file)
        allow(Digest::MD5).to receive(:digest)
        allow(Base64).to receive(:encode64).and_return("")
        allow(connection).to receive(:upload_part).and_return(double("response", headers: {}))

        cloud_io.send(:upload_parts,
          "/src/file", "dest/file", 1234, chunk_bytes, file_size)
        expect(Logger.messages.map(&:lines).join("\n")).to eq(
          "  Uploading 100 Parts...\n" \
          "  ...10% Complete...\n" \
          "  ...20% Complete...\n" \
          "  ...30% Complete...\n" \
          "  ...40% Complete...\n" \
          "  ...50% Complete...\n" \
          "  ...60% Complete...\n" \
          "  ...70% Complete...\n" \
          "  ...80% Complete...\n" \
          "  ...90% Complete..."
        )
      end
    end # describe '#upload_parts'

    describe "#complete_multipart" do
      let(:cloud_io) do
        CloudIO::S3.new(
          bucket: "my_bucket",
          max_retries: 1,
          retry_waitsec: 0
        )
      end
      let(:resp_ok) do
        double(
          "response",
          body: {
            "Location" => "http://my_bucket.s3.amazonaws.com/dest/file",
            "Bucket" => "my_bucket",
            "Key" => "dest/file",
            "ETag" => '"some-etag"'
          }
        )
      end
      let(:resp_bad) do
        double(
          "response",
          body: {
            "Code" => "InternalError",
            "Message" => "We encountered an internal error. Please try again."
          }
        )
      end

      before do
        allow(cloud_io).to receive(:connection).and_return(connection)
      end

      it "retries on raised errors" do
        expect(connection).to receive(:complete_multipart_upload).once
          .with("my_bucket", "dest/file", 1234, [:parts])
          .and_raise("error")
        expect(connection).to receive(:complete_multipart_upload).once
          .with("my_bucket", "dest/file", 1234, [:parts])
          .and_return(resp_ok)
        cloud_io.send(:complete_multipart, "dest/file", 1234, [:parts])
      end

      it "retries on returned errors" do
        expect(connection).to receive(:complete_multipart_upload).twice
          .with("my_bucket", "dest/file", 1234, [:parts])
          .and_return(resp_bad, resp_ok)
        cloud_io.send(:complete_multipart, "dest/file", 1234, [:parts])
      end

      it "fails after retries exceeded" do
        expect(connection).to receive(:complete_multipart_upload).once
          .with("my_bucket", "dest/file", 1234, [:parts])
          .and_raise("error message")
        expect(connection).to receive(:complete_multipart_upload).once
          .with("my_bucket", "dest/file", 1234, [:parts])
          .and_return(resp_bad)

        expect do
          cloud_io.send(:complete_multipart, "dest/file", 1234, [:parts])
        end.to raise_error CloudIO::Error, "CloudIO::Error: Max Retries (1) Exceeded!\n" \
          "  Operation: POST 'my_bucket/dest/file' (Complete)\n" \
          "  Be sure to check the log messages for each retry attempt.\n" \
          "--- Wrapped Exception ---\n" \
          "CloudIO::S3::Error: The server returned the following error:\n" \
          "  InternalError: We encountered an internal error. Please try again."
        expect(Logger.messages.map(&:lines).join("\n")).to eq(
          "  Complete Multipart 'my_bucket/dest/file'\n" \
          "CloudIO::Error: Retry #1 of 1\n" \
          "  Operation: POST 'my_bucket/dest/file' (Complete)\n" \
          "--- Wrapped Exception ---\n" \
          "RuntimeError: error message"
        )
      end
    end # describe '#complete_multipart'

    describe "#headers" do
      let(:cloud_io) { CloudIO::S3.new }

      it "returns empty headers by default" do
        allow(cloud_io).to receive(:encryption).and_return(nil)
        allow(cloud_io).to receive(:storage_class).and_return(nil)
        expect(cloud_io.send(:headers)).to eq({})
      end

      it "returns headers for server-side encryption" do
        allow(cloud_io).to receive(:storage_class).and_return(nil)
        ["aes256", :aes256].each do |arg|
          allow(cloud_io).to receive(:encryption).and_return(arg)
          expect(cloud_io.send(:headers)).to eq(
            "x-amz-server-side-encryption" => "AES256"
          )
        end
      end

      it "returns headers for reduced redundancy storage" do
        allow(cloud_io).to receive(:encryption).and_return(nil)
        ["reduced_redundancy", :reduced_redundancy].each do |arg|
          allow(cloud_io).to receive(:storage_class).and_return(arg)
          expect(cloud_io.send(:headers)).to eq(
            "x-amz-storage-class" => "REDUCED_REDUNDANCY"
          )
        end
      end

      it "returns headers for both" do
        allow(cloud_io).to receive(:encryption).and_return(:aes256)
        allow(cloud_io).to receive(:storage_class).and_return(:reduced_redundancy)
        expect(cloud_io.send(:headers)).to eq(
          "x-amz-server-side-encryption" => "AES256",
            "x-amz-storage-class" => "REDUCED_REDUNDANCY"
        )
      end

      it "returns empty headers for empty values" do
        allow(cloud_io).to receive(:encryption).and_return("")
        allow(cloud_io).to receive(:storage_class).and_return("")
        expect(cloud_io.send(:headers)).to eq({})
      end
    end # describe '#headers

    describe "Object" do
      let(:cloud_io) { CloudIO::S3.new }
      let(:obj_data) do
        { "Key" => "obj_key", "ETag" => "obj_etag", "StorageClass" => "STANDARD" }
      end
      let(:object) { CloudIO::S3::Object.new(cloud_io, obj_data) }

      describe "#initialize" do
        it "creates Object from data" do
          expect(object.key).to eq "obj_key"
          expect(object.etag).to eq "obj_etag"
          expect(object.storage_class).to eq "STANDARD"
        end
      end

      describe "#encryption" do
        it "returns the algorithm used for server-side encryption" do
          expect(cloud_io).to receive(:head_object).once.with(object).and_return(
            double("response", headers: { "x-amz-server-side-encryption" => "AES256" })
          )
          expect(object.encryption).to eq "AES256"
          expect(object.encryption).to eq "AES256"
        end

        it "returns nil if SSE was not used" do
          expect(cloud_io).to receive(:head_object).once.with(object)
            .and_return(double("response", headers: {}))
          expect(object.encryption).to be_nil
          expect(object.encryption).to be_nil
        end
      end # describe '#encryption'
    end # describe 'Object'
  end
end
