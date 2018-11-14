require "spec_helper"

module Backup
  describe Logger do
    let(:console_logger) { double("Console Logger") }
    let(:logfile_logger) { double("Logfile Logger") }
    let(:syslog_logger)  { double("Syslog Logger") }
    let(:default_loggers) { [console_logger, logfile_logger] }

    # Note: spec_helper calls Logger.reset! before each example
    before do
      allow(Logger::Console).to receive(:new)
        .with(kind_of(Logger::Console::Options))
        .and_return(console_logger)
      allow(Logger::Logfile).to receive(:new)
        .with(kind_of(Logger::Logfile::Options))
        .and_return(logfile_logger)
      allow(Logger::Syslog).to receive(:new)
        .with(kind_of(Logger::Syslog::Options))
        .and_return(syslog_logger)
    end

    describe Logger::Message do
      describe "#initialize" do
        it "returns a new message object" do
          Timecop.freeze do
            msg = Logger::Message.new(Time.now, :log_level, ["message", "lines"])
            expect(msg.time).to eq(Time.now)
            expect(msg.level).to eq(:log_level)
            expect(msg.lines).to eq(["message", "lines"])
          end
        end
      end

      describe "#formatted_lines" do
        it "returns the message lines formatted" do
          Timecop.freeze do
            timestamp = Time.now.strftime("%Y/%m/%d %H:%M:%S")
            msg = Logger::Message.new(Time.now, :log_level, ["message", "lines"])
            expect(msg.formatted_lines).to eq([
              "[#{timestamp}][log_level] message",
              "[#{timestamp}][log_level] lines"
            ])
          end
        end

        it "preserves blank lines in messages" do
          Timecop.freeze do
            timestamp = Time.now.strftime("%Y/%m/%d %H:%M:%S")
            msg = Logger::Message.new(Time.now, :log_level, ["message", "", "lines"])
            expect(msg.formatted_lines).to eq([
              "[#{timestamp}][log_level] message",
              "[#{timestamp}][log_level] ",
              "[#{timestamp}][log_level] lines"
            ])
          end
        end
      end

      describe "#matches?" do
        let(:message) do
          Logger::Message.new(
            :foo, :foo, ["line one of message", "line two of message"]
          )
        end

        it "returns true if message lines match the given matchers" do
          expect(message.matches?(["not", "one of"])).to be(true)
          expect(message.matches?(["not", "message\nline two"])).to be(true)
          expect(message.matches?(["not", /^line one/])).to be(true)
          expect(message.matches?(["not", /two \w+ message$/])).to be(true)
        end

        it "returns false if no match is found" do
          expect(message.matches?(["not", "three"])).to be(false)
          expect(message.matches?(["not", /three/])).to be(false)
        end
      end
    end # describe Logger::Message

    describe ".configure" do
      context "when the console and logfile loggers are enabled" do
        before do
          expect(Logger::Syslog).to receive(:new).never
          Logger.info "line 1\nline 2"
          Logger.configure do
            console.quiet   = false
            logfile.enabled = true
            syslog.enabled  = false
          end
        end

        it "sends messages to only the enabled loggers" do
          expect(console_logger).to receive(:log) do |msg|
            expect(msg.lines).to eq(["line 1", "line 2"])
          end

          expect(logfile_logger).to receive(:log) do |msg|
            expect(msg.lines).to eq(["line 1", "line 2"])
          end

          expect(syslog_logger).to receive(:log).never

          Logger.start!
        end
      end

      context "when the logfile and syslog loggers are enabled" do
        before do
          expect(Logger::Console).to receive(:new).never
          Logger.info "line 1\nline 2"
          Logger.configure do
            console.quiet   = true
            logfile.enabled = true
            syslog.enabled  = true
          end
        end

        it "sends messages to only the enabled loggers" do
          expect(console_logger).to receive(:log).never

          expect(logfile_logger).to receive(:log) do |msg|
            expect(msg.lines).to eq(["line 1", "line 2"])
          end

          expect(syslog_logger).to receive(:log) do |msg|
            expect(msg.lines).to eq(["line 1", "line 2"])
          end

          Logger.start!
        end
      end

      context "when the console and syslog loggers are enabled" do
        before do
          expect(Logger::Logfile).to receive(:new).never
          Logger.info "line 1\nline 2"
          Logger.configure do
            console.quiet   = false
            logfile.enabled = false
            syslog.enabled  = true
          end
        end

        it "sends messages to only the enabled loggers" do
          expect(console_logger).to receive(:log) do |msg|
            expect(msg.lines).to eq(["line 1", "line 2"])
          end

          expect(logfile_logger).to receive(:log).never

          expect(syslog_logger).to receive(:log) do |msg|
            expect(msg.lines).to eq(["line 1", "line 2"])
          end

          Logger.start!
        end
      end

      # Note that this will only work for :warn messages
      # sent *after* the Logger has been configured.
      context "when warnings are ignored" do
        before do
          Logger.configure do
            ignore_warning "one\nline two"
            ignore_warning(/line\nline two/)
          end
        end

        it "converts ignored :warn messages to :info messages" do
          Logger.warn "message line one\nline two"
          Logger.warn "first line\nline two of message"
          Logger.warn "first line\nsecond line"
          Logger.error "one of"
          m1, m2, m3, m4 = Logger.messages

          expect(m1.level).to be(:info)
          expect(m2.level).to be(:info)
          expect(m3.level).to be(:warn)
          expect(m4.level).to be(:error)

          expect(Logger.has_warnings?).to be(true)
          expect(Logger.has_errors?).to be(true)
        end

        it "does not flag logger as having warnings" do
          Logger.warn "message line one\nline two"
          Logger.warn "first line\nline two of message"

          expect(Logger.has_warnings?).to be(false)
        end
      end
    end # describe '.configure'

    describe ".start!" do
      context "before the Logger is started" do
        it "only stores the messages to be sent" do
          default_loggers.each { |logger| expect(logger).to receive(:log).never }

          Logger.info "a message"
          expect(Logger.messages.first.lines).to eq(["a message"])
        end

        it "does not instantiate any loggers" do
          expect(Logger::Console).to receive(:new).never
          expect(Logger::Logfile).to receive(:new).never
          expect(Logger::Syslog).to receive(:new).never

          Logger.info "a message"
          expect(Logger.send(:logger).instance_variable_get(:@loggers)).to be_empty
        end
      end

      context "when Logger is started" do
        before do
          Logger.info "info message"
          Logger.warn "warn message"
          Logger.error "error message"
        end

        it "sends all messages sent before being started" do
          Logger.messages.each do |msg|
            default_loggers.each do |logger|
              expect(logger).to receive(:log).ordered.with(msg)
            end
          end

          Logger.start!
        end
      end

      context "after the Logger is started" do
        it "stores and sends messages" do
          default_loggers.each do |logger|
            expect(logger).to receive(:log) do |msg|
              expect(msg.lines).to eq(["a message"])
            end
          end

          Logger.start!
          Logger.info "a message"
          expect(Logger.messages.first.lines).to eq(["a message"])
        end

        it "instantiates all enabled loggers" do
          Logger.start!
          expect(Logger.send(:logger).instance_variable_get(:@loggers))
            .to eq(default_loggers)
        end
      end
    end # describe '.start!'

    describe "log messaging methods" do
      before do
        expect(Logger::MUTEX).to receive(:synchronize).and_yield
      end

      describe ".info" do
        it "sends messages with log level :info" do
          Logger.info "info message"
          msg = Logger.messages.last
          expect(msg.level).to eq(:info)
          expect(msg.lines).to eq(["info message"])

          default_loggers.each { |logger| expect(logger).to receive(:log).with(msg) }
          Logger.start!
        end
      end

      describe ".warn" do
        it "sends messages with log level :warn" do
          Logger.warn "warn message"
          msg = Logger.messages.last
          expect(msg.level).to eq(:warn)
          expect(msg.lines).to eq(["warn message"])

          default_loggers.each { |logger| expect(logger).to receive(:log).with(msg) }
          Logger.start!
        end
      end

      describe ".error" do
        it "sends messages with log level :error" do
          Logger.error "error message"
          msg = Logger.messages.last
          expect(msg.level).to eq(:error)
          expect(msg.lines).to eq(["error message"])

          default_loggers.each { |logger| expect(logger).to receive(:log).with(msg) }
          Logger.start!
        end
      end

      it "accepts objects responding to #to_s" do
        Logger.info StandardError.new("message")
        msg = Logger.messages.last
        expect(msg.level).to eq(:info)
        expect(msg.lines).to eq(["message"])
      end

      it "preserves blank lines in messages" do
        Logger.info "line one\n\nline two"
        msg = Logger.messages.last
        expect(msg.level).to eq(:info)
        expect(msg.lines).to eq(["line one", "", "line two"])
      end

      it "logs messages with UTC time" do
        Logger.info "message"
        msg = Logger.messages.last
        expect(msg.time).to be_utc
      end
    end # describe 'log messaging methods'

    describe ".has_warnings?" do
      context "when messages with :warn log level are sent" do
        it "returns true" do
          Logger.warn "warn message"
          expect(Logger.has_warnings?).to eq(true)
        end
      end

      context "when no messages with :warn log level are sent" do
        it "returns false" do
          Logger.info "info message"
          Logger.error "error message"
          expect(Logger.has_warnings?).to eq(false)
        end
      end
    end

    describe ".has_errors?" do
      context "when messages with :error log level are sent" do
        it "returns true" do
          Logger.error "error message"
          expect(Logger.has_errors?).to eq(true)
        end
      end

      context "when no messages with :warn log level are sent" do
        it "returns false" do
          Logger.info "info message"
          Logger.warn "warn message"
          expect(Logger.has_errors?).to eq(false)
        end
      end
    end

    describe ".clear!" do
      before do
        Logger.info "info message"
        Logger.warn "warn message"
        Logger.error "error message"

        expect(Logger.messages.count).to be(3)
        expect(Logger.has_warnings?).to eq(true)
        expect(Logger.has_errors?).to eq(true)

        @initial_logger = Logger.instance_variable_get(:@logger)
        Logger.clear!
        @current_logger = Logger.instance_variable_get(:@logger)
      end

      it "clears all stored messages" do
        expect(Logger.messages).to be_empty
      end

      it "resets has_warnings? to false" do
        expect(Logger.has_warnings?).to eq(false)
      end

      it "resets has_errors? to false" do
        expect(Logger.has_errors?).to eq(false)
      end

      it "replaces the logger" do
        expect(@current_logger).to be_a(Backup::Logger)
        expect(@current_logger).to_not be(@initial_logger)
      end

      it "starts the new logger" do
        expect(@current_logger.instance_variable_get(:@loggers)).to eq(default_loggers)
      end
    end

    describe ".abort!" do
      before do
        allow(Logger::Console).to receive(:new)
          .with(no_args)
          .and_return(console_logger)
        expect(Logger::Logfile).to receive(:new).never
        expect(Logger::Syslog).to receive(:new).never

        Logger.info "info message"
        Logger.warn "warn message"
        Logger.error "error message"
      end

      it "dumps all messages via a new console logger" do
        expect(logfile_logger).to receive(:log).never
        expect(console_logger).to receive(:log).exactly(3).times
        Logger.abort!
      end
    end
  end
end
