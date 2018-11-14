require "spec_helper"

module Backup
  describe Logger::Syslog do
    before do
      expect_any_instance_of(Logger::Console).to receive(:log).never
      expect_any_instance_of(Logger::Logfile).to receive(:log).never
      Logger.configure do
        console.quiet = true
        logfile.enabled = false
        syslog.enabled = true
      end
    end

    describe "syslog logger configuration" do
      it "may be disabled via Logger.configure" do
        Logger.configure do
          syslog.enabled = false
        end
        Logger.start!

        expect_any_instance_of(Logger::Syslog).to receive(:log).never
        Logger.info "message"
      end

      it "may be forced disabled via the command line" do
        Logger.configure do
          # --no-syslog should set this to nil
          syslog.enabled = nil
        end
        Logger.configure do
          # attempt to enable once set to nil will be ignored
          syslog.enabled = true
        end
        Logger.start!

        expect_any_instance_of(Logger::Syslog).to receive(:log).never
        Logger.info "message"
      end
    end

    describe "console logger usage" do
      let(:syslog_logger) { double }
      let(:s) { sequence "" }

      before do
        Logger.configure do
          syslog.ident = "test ident"
          syslog.facility = ::Syslog::LOG_LOCAL4
        end

        expect(::Syslog).to receive(:open).with(
          "test ident", ::Syslog::LOG_PID, ::Syslog::LOG_LOCAL4
        ).and_yield(syslog_logger)

        Logger.start!
      end

      context "when sending an :info message" do
        it "sends info messages to syslog" do
          expect(syslog_logger).to receive(:log).ordered.with(
            ::Syslog::LOG_INFO, "%s", "message line one"
          )
          expect(syslog_logger).to receive(:log).ordered.with(
            ::Syslog::LOG_INFO, "%s", "message line two"
          )
          Logger.info "message line one\nmessage line two"
        end
      end

      context "when sending an :warn message" do
        it "sends warn messages to syslog" do
          expect(syslog_logger).to receive(:log).ordered.with(
            ::Syslog::LOG_WARNING, "%s", "message line one"
          )
          expect(syslog_logger).to receive(:log).ordered.with(
            ::Syslog::LOG_WARNING, "%s", "message line two"
          )
          Logger.warn "message line one\nmessage line two"
        end
      end

      context "when sending an :error message" do
        it "sends error messages to syslog" do
          expect(syslog_logger).to receive(:log).ordered.with(
            ::Syslog::LOG_ERR, "%s", "message line one"
          )
          expect(syslog_logger).to receive(:log).ordered.with(
            ::Syslog::LOG_ERR, "%s", "message line two"
          )
          Logger.error "message line one\nmessage line two"
        end
      end
    end
  end
end
