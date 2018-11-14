require "spec_helper"

module Backup
  describe Logger::Console do
    let(:timestamp) { Time.now.utc.strftime("%Y/%m/%d %H:%M:%S") }

    before do
      expect_any_instance_of(Logger::Logfile).to receive(:log).never
      expect_any_instance_of(Logger::Syslog).to receive(:log).never
      Logger.configure do
        logfile.enabled = false
        syslog.enabled = false
        console.quiet = false
      end
    end

    describe "console logger configuration" do
      it "may be disabled via Logger.configure" do
        Logger.configure do
          console.quiet = true
        end
        Logger.start!

        expect_any_instance_of(Logger::Console).to receive(:log).never
        Logger.info "message"
      end

      it "may be forced enabled via the command line" do
        Logger.configure do
          # --no-quiet should set this to nil
          console.quiet = nil
        end
        Logger.configure do
          # attempt to disable once set to nil will be ignored
          console.quiet = true
        end
        Logger.start!

        expect_any_instance_of(Logger::Console).to receive(:log)
        Logger.info "message"
      end
    end

    describe "console logger usage" do
      before { Logger.start! }

      context "when IO is attached to a terminal" do
        before do
          allow($stdout).to receive(:tty?).and_return(true)
          allow($stderr).to receive(:tty?).and_return(true)
        end

        it "sends colorized, formatted :info message to $stdout" do
          expect($stderr).to receive(:puts).never
          Timecop.freeze do
            expect($stdout).to receive(:puts).with([
              "\e[32m[#{timestamp}][info] message line one\e[0m",
              "\e[32m[#{timestamp}][info] message line two\e[0m"
            ])
            Logger.info "message line one\nmessage line two"
          end
        end

        it "sends colorized, formatted :warn message to $stderr" do
          expect($stdout).to receive(:puts).never
          Timecop.freeze do
            expect($stderr).to receive(:puts).with([
              "\e[33m[#{timestamp}][warn] message line one\e[0m",
              "\e[33m[#{timestamp}][warn] message line two\e[0m"
            ])
            Logger.warn "message line one\nmessage line two"
          end
        end

        it "sends colorized, formatted :error message to $stderr" do
          expect($stdout).to receive(:puts).never
          Timecop.freeze do
            expect($stderr).to receive(:puts).with([
              "\e[31m[#{timestamp}][error] message line one\e[0m",
              "\e[31m[#{timestamp}][error] message line two\e[0m"
            ])
            Logger.error "message line one\nmessage line two"
          end
        end
      end # context 'when IO is attached to a terminal'

      context "when IO is not attached to a terminal" do
        before do
          allow($stdout).to receive(:tty?).and_return(false)
          allow($stderr).to receive(:tty?).and_return(false)
        end

        it "sends non-colorized, formatted :info message to $stdout" do
          expect($stderr).to receive(:puts).never
          Timecop.freeze do
            expect($stdout).to receive(:puts).with([
              "[#{timestamp}][info] message line one",
              "[#{timestamp}][info] message line two"
            ])
            Logger.info "message line one\nmessage line two"
          end
        end

        it "sends non-colorized, formatted :warn message to $stderr" do
          expect($stdout).to receive(:puts).never
          Timecop.freeze do
            expect($stderr).to receive(:puts).with([
              "[#{timestamp}][warn] message line one",
              "[#{timestamp}][warn] message line two"
            ])
            Logger.warn "message line one\nmessage line two"
          end
        end

        it "sends non-colorized, formatted :error message to $stderr" do
          expect($stdout).to receive(:puts).never
          Timecop.freeze do
            expect($stderr).to receive(:puts).with([
              "[#{timestamp}][error] message line one",
              "[#{timestamp}][error] message line two"
            ])
            Logger.error "message line one\nmessage line two"
          end
        end
      end # context 'when IO is not attached to a terminal'
    end
  end
end
