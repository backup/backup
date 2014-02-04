# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Logger::Syslog do

  before do
    Logger::Console.any_instance.expects(:log).never
    Logger::Logfile.any_instance.expects(:log).never
    Logger.configure do
      console.quiet = true
      logfile.enabled = false
      syslog.enabled = true
    end
  end

  describe 'syslog logger configuration' do
    it 'may be disabled via Logger.configure' do
      Logger.configure do
        syslog.enabled = false
      end
      Logger.start!

      Logger::Syslog.any_instance.expects(:log).never
      Logger.info 'message'
    end

    it 'may be forced disabled via the command line' do
      Logger.configure do
        # --no-syslog should set this to nil
        syslog.enabled = nil
      end
      Logger.configure do
        # attempt to enable once set to nil will be ignored
        syslog.enabled = true
      end
      Logger.start!

      Logger::Syslog.any_instance.expects(:log).never
      Logger.info 'message'
    end
  end

  describe 'console logger usage' do
    let(:syslog_logger) { mock }
    let(:s) { sequence '' }

    before do
      Logger.configure do
        syslog.ident = 'test ident'
        syslog.facility = ::Syslog::LOG_LOCAL4
      end

      ::Syslog.expects(:open).with(
        'test ident', ::Syslog::LOG_PID, ::Syslog::LOG_LOCAL4
      ).yields(syslog_logger)

      Logger.start!
    end

    context 'when sending an :info message' do
      it 'sends info messages to syslog' do
        syslog_logger.expects(:log).in_sequence(s).with(
          ::Syslog::LOG_INFO, '%s', 'message line one'
        )
        syslog_logger.expects(:log).in_sequence(s).with(
          ::Syslog::LOG_INFO, '%s', 'message line two'
        )
        Logger.info "message line one\nmessage line two"
      end
    end

    context 'when sending an :warn message' do
      it 'sends warn messages to syslog' do
        syslog_logger.expects(:log).in_sequence(s).with(
          ::Syslog::LOG_WARNING, '%s', 'message line one'
        )
        syslog_logger.expects(:log).in_sequence(s).with(
          ::Syslog::LOG_WARNING, '%s', 'message line two'
        )
        Logger.warn "message line one\nmessage line two"
      end
    end

    context 'when sending an :error message' do
      it 'sends error messages to syslog' do
        syslog_logger.expects(:log).in_sequence(s).with(
          ::Syslog::LOG_ERR, '%s', 'message line one'
        )
        syslog_logger.expects(:log).in_sequence(s).with(
          ::Syslog::LOG_ERR, '%s', 'message line two'
        )
        Logger.error "message line one\nmessage line two"
      end
    end
  end
end
end
