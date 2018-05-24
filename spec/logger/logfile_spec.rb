require "spec_helper"

module Backup
  describe Logger::Logfile do
    before do
      @tmpdir = Dir.mktmpdir("backup_spec")
      SandboxFileUtils.activate!(@tmpdir)

      @log_path_absolute = File.join(@tmpdir, "log_path")
      @logfile_absolute = File.join(@log_path_absolute, "backup.log")
      @root_path = File.join(@tmpdir, "root_dir")
      @log_path_rel = File.join(@root_path, "log_path_rel")
      @log_path_default = File.join(@root_path, "log")
      @logfile_default = File.join(@log_path_default, "backup.log")

      Backup::Config.stubs(:root_path).returns(@root_path)

      Logger::Console.any_instance.expects(:log).never
      Logger::Syslog.any_instance.expects(:log).never
      Logger.configure do
        console.quiet = true
        logfile.enabled = true
        syslog.enabled = false
      end
    end

    after do
      FileUtils.rm_r(@tmpdir, force: true, secure: true)
    end

    describe "logfile logger configuration" do
      it "may be disabled via Logger.configure" do
        Logger.configure do
          logfile.enabled = false
        end
        Logger.start!

        Logger::Syslog.any_instance.expects(:log).never
        Logger.info "message"
        expect(File.exist?(@log_path_default)).to eq(false)
      end

      it "may be forced disabled via the command line" do
        Logger.configure do
          # --no-logfile should set this to nil
          logfile.enabled = nil
        end
        Logger.configure do
          # attempt to enable once set to nil will be ignored
          logfile.enabled = true
        end
        Logger.start!

        Logger::Syslog.any_instance.expects(:log).never
        Logger.info "message"
        expect(File.exist?(@log_path_default)).to eq(false)
      end

      it "ignores log_path setting if it is already set" do
        Logger.configure do
          # path set using --log-path on the command line
          logfile.log_path = "log_path_rel"
        end
        Logger.configure do
          # attempt to set in config.rb will be ignored
          logfile.log_path = "log"
        end

        Logger.start!

        expect(File.exist?(@log_path_default)).to eq(false)
        expect(File.exist?(@log_path_absolute)).to eq(false)
        expect(File.exist?(@log_path_rel)).to eq(true)
      end
    end

    describe "#initialize" do
      describe "log_path creation" do
        context "when log_path is not set" do
          before do
            Logger.start!
          end

          it "should create the default log_path" do
            expect(File.exist?(@log_path_rel)).to eq(false)
            expect(File.exist?(@log_path_absolute)).to eq(false)
            expect(File.exist?(@log_path_default)).to eq(true)
          end
        end

        context "when log_path is set using an absolute path" do
          before do
            path = @log_path_absolute
            Logger.configure do
              logfile.log_path = path
            end
            Logger.start!
          end

          it "should create the absolute log_path" do
            expect(File.exist?(@log_path_default)).to eq(false)
            expect(File.exist?(@log_path_rel)).to eq(false)
            expect(File.exist?(@log_path_absolute)).to eq(true)
          end
        end

        context "when log_path is set as a relative path" do
          before do
            Logger.configure do
              logfile.log_path = "log_path_rel"
            end
            Logger.start!
          end

          it "should create the log_path relative to Backup::Config.root_path" do
            expect(File.exist?(@log_path_default)).to eq(false)
            expect(File.exist?(@log_path_absolute)).to eq(false)
            expect(File.exist?(@log_path_rel)).to eq(true)
          end
        end
      end # describe 'log_path creation'

      describe "logfile truncation" do
        before do
          Logger.configure do
            logfile.max_bytes = 1000
          end
        end

        context "when log file is larger than max_bytes" do
          before do
            FileUtils.mkdir_p(@log_path_default)
          end

          it "should truncate the file, removing older lines" do
            lineno = 0
            File.open(@logfile_default, "w") do |file|
              bytes = 0
              until bytes > 1200
                bytes += file.write((lineno += 1).to_s.ljust(120, "x") + "\n")
              end
            end
            expect(File.stat(@logfile_default).size).to be >= 1200

            Logger.start!
            expect(File.stat(@logfile_default).size).to be <= 1000
            expect(File.readlines(@logfile_default).last).to match(/#{ lineno }x/)
            expect(File.exist?(@logfile_default + "~")).to eq(false)
          end
        end

        context "when log file is not larger than max_bytes" do
          it "does not truncates the file" do
            File.expects(:mv).never
            Logger.start!
            Logger.info "a message"

            expect(File.stat(@logfile_default).size).to be > 0
            expect(File.stat(@logfile_default).size).to be < 500
            expect(File.exist?(@log_path_default)).to eq(true)
            expect(File.exist?(@logfile_default)).to eq(true)
          end
        end

        context "when log file does not exist" do
          it "does not truncates the file" do
            File.expects(:mv).never
            Logger.start!
            expect(File.exist?(@log_path_default)).to eq(true)
            expect(File.exist?(@logfile_default)).to eq(false)
          end
        end
      end # describe 'logfile truncation'
    end # describe '#initialize'

    describe "#log" do
      let(:timestamp) { Time.now.utc.strftime("%Y/%m/%d %H:%M:%S") }

      before do
        Logger.start!
      end

      it "writes formatted messages to the log file" do
        Timecop.freeze do
          Logger.info "line one\nline two"
          expect(File.readlines(@logfile_default)).to eq([
            "[#{timestamp}][info] line one\n",
            "[#{timestamp}][info] line two\n"
          ])
        end
      end

      it "preserves blank lines within the messages" do
        Timecop.freeze do
          Logger.info "line one\n\nline two"
          expect(File.readlines(@logfile_default)).to eq([
            "[#{timestamp}][info] line one\n",
            "[#{timestamp}][info] \n",
            "[#{timestamp}][info] line two\n"
          ])
        end
      end
    end # describe '#log'
  end
end
