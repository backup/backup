require "spec_helper"

describe Backup::Archive do
  def expect_log(level, message)
    Backup::Logger.expects(level).with(message)
  end

  def expect_no_log(level, message)
    Backup::Logger.expects(level).with(message).never
  end

  let(:model) { Backup::Model.new(:test_trigger, "test model") }

  describe "#initialize" do
    context "without configure block" do
      let(:archive) { Backup::Archive.new(model, :unconfigured_archive) }

      it "sets default values" do
        expect(archive.name).to eq "unconfigured_archive"
        expect(archive.options).to eq(
          sudo: false,
          root: false,
          paths: [],
          excludes: [],
          tar_options: ""
        )
      end
    end

    context "with configure block" do
      let(:archive) do
        Backup::Archive.new(model, :configured_archive) do |a|
          a.use_sudo
          a.root "root/path"
          a.add "a/path"
          a.add "/another/path"
          a.exclude "excluded/path"
          a.exclude "/another/excluded/path"
          a.tar_options "-h --xattrs"
        end
      end

      it "sets configured values" do
        expect(archive.name).to eq "configured_archive"
        expect(archive.options).to eq(
          sudo: true,
          root: "root/path",
          paths: ["a/path", "/another/path"],
          excludes: ["excluded/path", "/another/excluded/path"],
          tar_options: "-h --xattrs"
        )
      end
    end
  end

  describe "#perform!" do
    before do
      # TODO: No/less stubs
      Backup::Archive.any_instance.stubs(:utility).with(:tar).returns("tar")
      Backup::Archive.any_instance.stubs(:utility).with(:cat).returns("cat")
      Backup::Archive.any_instance.stubs(:utility).with(:sudo).returns("sudo")
      Backup::Archive.any_instance.stubs(:with_files_from).yields("")
      Backup::Config.stubs(:tmp_path).returns("/tmp/path")
      Backup::Pipeline.any_instance.stubs(:success?).returns(true)
    end

    describe "results" do
      let(:archive) { Backup::Archive.new(model, :my_archive) }

      it "logs info messages on success" do
        # TODO: Capture logs some better way and test the contents of the log
        # rather than method calls.
        expect_log :info, "Creating Archive 'my_archive'..."
        expect_log :info, "Archive 'my_archive' Complete!"

        archive.perform!
      end

      it "raises error on failure" do
        Backup::Pipeline.any_instance.stubs(:success?).returns(false)
        Backup::Pipeline.any_instance.stubs(:error_messages).returns("error messages")

        expect_log :info, "Creating Archive 'my_archive'..."
        expect_no_log :info, "Archive 'my_archive' Complete!"

        expect { archive.perform! }.to raise_error Backup::Archive::Error,
          "Archive::Error: Failed to Create Archive 'my_archive'\n  error messages"
      end
    end

    describe "using GNU tar" do
      before do
        Backup::Pipeline.any_instance.expects(:<<).with(
          "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
        )
      end
      after { archive.perform! }

      context "without tar options" do
        let(:archive) { Backup::Archive.new(model, :my_archive) }

        it "returns GNU tar options" do
          Backup::Pipeline.any_instance.expects(:add).with(
            "tar --ignore-failed-read -cPf -  ", [0, 1]
          )
        end
      end

      context "with tar_options" do
        let(:archive) do
          Backup::Archive.new(model, :my_archive) do |a|
            a.tar_options "-h --xattrs"
          end
        end

        it "prepends GNU tar options" do
          Backup::Pipeline.any_instance.expects(:add).with(
            "tar --ignore-failed-read -h --xattrs -cPf -  ", [0, 1]
          )
        end
      end
    end

    describe "using BSD tar" do
      before do
        Backup::Archive.any_instance.stubs(:gnu_tar?).returns(false)
        Backup::Pipeline.any_instance.expects(:<<).with(
          "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
        )
      end
      after { archive.perform! }

      context "without tar_options" do
        let(:archive) { Backup::Archive.new(model, :my_archive) }

        it "returns no GNU options" do
          Backup::Pipeline.any_instance.expects(:add).with("tar  -cPf -  ", [0])
        end
      end

      context "with tar_options" do
        let(:archive) do
          Backup::Archive.new(model, :my_archive) do |a|
            a.tar_options "-h --xattrs"
          end
        end

        it "returns only the configured options" do
          Backup::Pipeline.any_instance.expects(:add).with("tar -h --xattrs -cPf -  ", [0])
        end
      end
    end

    describe "root path option" do
      after { archive.perform! }

      context "when a root path is given" do
        let(:archive) do
          Backup::Archive.new(model, :my_archive) do |a|
            a.root "root/path"
            a.add "this/path"
            a.add "/that/path"
            a.exclude "other/path"
            a.exclude "/another/path"
          end
        end

        it "changes directories to create relative path archives" do
          archive.expects(:with_files_from).with(
            ["this/path", "/that/path"]
          ).yields("-T '/path/to/tmpfile'")

          Backup::Pipeline.any_instance.expects(:add).with(
            "tar --ignore-failed-read -cPf - " \
            "-C '#{File.expand_path("root/path")}' " \
            "--exclude='other/path' --exclude='/another/path' " \
            "-T '/path/to/tmpfile'",
            [0, 1]
          )
          Backup::Pipeline.any_instance.expects(:<<).with(
            "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
          )
        end
      end

      context "when no root path is given" do
        let(:archive) do
          Backup::Archive.new(model, :my_archive) do |a|
            a.add "this/path"
            a.add "/that/path"
            a.exclude "other/path"
            a.exclude "/another/path"
          end
        end

        it "creates archives with expanded paths" do
          archive.expects(:with_files_from).with(
            [File.expand_path("this/path"), "/that/path"]
          ).yields("-T '/path/to/tmpfile'")

          Backup::Pipeline.any_instance.expects(:add).with(
            "tar --ignore-failed-read -cPf - " \
            "--exclude='#{File.expand_path("other/path")}' " \
            "--exclude='/another/path' " \
            "-T '/path/to/tmpfile'",
            [0, 1]
          )
          Backup::Pipeline.any_instance.expects(:<<).with(
            "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
          )
        end
      end
    end

    describe "compressor usage" do
      let(:archive) { Backup::Archive.new(model, :my_archive) }
      after { archive.perform! }

      it "creates a compressed archive" do
        compressor = mock
        model.stubs(:compressor).returns(compressor)
        compressor.stubs(:compress_with).yields("comp_command", ".comp_ext")

        Backup::Pipeline.any_instance.expects(:<<).with("comp_command")
        Backup::Pipeline.any_instance.expects(:<<).with(
          "cat > '/tmp/path/test_trigger/archives/my_archive.tar.comp_ext'"
        )
      end

      it "creates an uncompressed archive" do
        Backup::Pipeline.any_instance.expects(:<<).with("comp_command").never
        Backup::Pipeline.any_instance.expects(:<<).with(
          "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
        )
      end
    end

    context "with use_sudo" do
      let(:archive) { Backup::Archive.new(model, :my_archive, &:use_sudo) }
      after { archive.perform! }

      it "uses sudo" do
        Backup::Pipeline.any_instance.expects(:add).with(
          "sudo -n tar --ignore-failed-read -cPf -  ", [0, 1]
        )
        Backup::Pipeline.any_instance.expects(:<<).with(
          "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
        )
      end
    end
  end

  # TODO: No testing private methods directly. Incorporate it in the #perform
  # tests.
  describe "#with_files_from" do
    let(:archive) { Backup::Archive.new(model, :test_archive) {} }
    let(:s) { sequence "" }
    let(:tmpfile) { stub(path: "/path/to/tmpfile") }
    let(:paths) { ["this/path", "/that/path"] }

    # -T is used for BSD compatibility
    it "yields the tar --files-from option" do
      Tempfile.expects(:new).in_sequence(s).returns(tmpfile)
      tmpfile.expects(:puts).in_sequence(s).with("this/path")
      tmpfile.expects(:puts).in_sequence(s).with("/that/path")
      tmpfile.expects(:close).in_sequence(s)
      tmpfile.expects(:delete).in_sequence(s)

      archive.send(:with_files_from, paths) do |files_from|
        expect(files_from).to eq "-T '/path/to/tmpfile'"
      end
    end

    it "ensures the tmpfile is removed" do
      Tempfile.expects(:new).returns(tmpfile)
      tmpfile.expects(:close)
      tmpfile.expects(:delete)
      expect { archive.send(:with_files_from, []) { raise "foo" } }.to raise_error("foo")
    end

    it "writes the given paths to a tempfile" do
      archive.send(:with_files_from, paths) do |files_from|
        path = files_from.match(/-T '(.*)'/)[1]
        expect(File.read(path)).to eq "this/path\n/that/path\n"
      end
    end
  end
end
