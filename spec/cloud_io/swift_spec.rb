require File.expand_path("../../spec_helper.rb", __FILE__)
require "backup/cloud_io/swift"

module Backup
  describe CloudIO::Swift do
    let(:connection) { mock }
    let(:directory) { mock }
    let(:files) { mock }
    let(:fd) { mock }
    let(:response) { mock }
    let(:cloud_io) do
      CloudIO::Swift.new(container: "my_bucket", batch_size: 5, max_retries: 0)
    end

    describe "#upload" do
      context "when file is larger than 5GB" do
        before do
          File.expects(:size).with("/src/file").returns(5 * 1024**3)
        end

        it "raises an error" do
          expect do
            cloud_io.upload("/src/file", "idontcare")
          end.to raise_error CloudIO::FileSizeError
        end
      end

      context "when file is smaller than 5GB" do
        before do
          File.expects(:size).with("/src/file").returns(512)
          File.expects(:open).with("/src/file").returns(fd)
        end

        it "class #create on the directory" do
          cloud_io.expects(:directory).returns(directory)
          directory.expects(:files).returns(files)
          files.expects(:create).with(key: "/dst/file", body: fd)

          cloud_io.upload("/src/file", "/dst/file")
        end
      end
    end

    describe "#objects" do
      it "call #files on the container model" do
        cloud_io.expects(:directory).twice.returns(directory)
        directory.expects(:files).twice.returns(files)
        files.expects(:all).twice.with(prefix: "/prefix/")

        cloud_io.objects("/prefix")
        cloud_io.objects("/prefix/")
      end
    end

    describe "#delete" do
      let(:key_1) { ["file/path"] }
      let(:key_10) { (0...10).to_a.map { |id| "/path/to/file/#{id}" } }
      before do
        cloud_io.expects(:connection).returns(connection)
      end

      it "calls connection#delete_multiple_objects" do
        connection.expects(:delete_multiple_objects)
          .with("my_bucket", key_1)
          .returns(response)
        response.expects(:data).returns(status: 200)

        expect { cloud_io.delete key_1 }.to_not raise_error
      end

      it "raises an error if status != 200" do
        response.expects(:data).at_least(1).returns(
          status: 503,
          reason_phrase: "give me a reason",
          body: "bodybody"
        )
        connection.expects(:delete_multiple_objects)
          .with("my_bucket", key_1)
          .returns(response)

        expect { cloud_io.delete key_1 }.to raise_error { |err|
          expect(err.message).to match(/Failed to delete/)
          expect(err.message).to match(/503/)
          expect(err.message).to match(/give me a reason/)
          expect(err.message).to match(/bodybody/)
        }
      end
    end
  end
end
