# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)
require 'timecop'

describe Backup::Logger do
  before do
    Timecop.freeze(Time.now)

    [:message, :error, :warn, :normal, :silent].each do |message_type|
      Backup::Logger.unstub(message_type)
    end
  end

  describe 'logging messages to STDOUT and a log file' do
    before do
      File.expects(:open).with(File.join(Backup::LOG_PATH, 'backup.log'), 'a')
    end

    context 'when logging regular messages' do
      it do
        Backup::Logger.expects(:puts).with("[#{ Time.now.strftime("%Y/%m/%d %H:%M:%S") }][\e[32mmessage\e[0m] This has been logged.")

        Backup::Logger.message "This has been logged."
      end
    end

    context 'when logging error messages' do
      it do
        Backup::Logger.expects(:puts).with("[#{ Time.now.strftime("%Y/%m/%d %H:%M:%S") }][\e[31merror\e[0m] This has been logged.")

        Backup::Logger.error "This has been logged."
      end
    end

    context 'when logging warn messages' do
      it do
        Backup::Logger.expects(:puts).with("[#{ Time.now.strftime("%Y/%m/%d %H:%M:%S") }][\e[33mwarning\e[0m] This has been logged.")

        Backup::Logger.warn "This has been logged."
      end
    end

    context 'when logging silent messages' do
      it do
        Backup::Logger.expects(:puts).never

        Backup::Logger.silent "This has been logged."
      end
    end
  end

  describe 'logging messages to log file and not STDOUT' do
    it do
      Backup::Logger.send(:const_set, :QUIET, true)

      Backup::Logger.expects(:puts).never
      File.expects(:open).times(4).with(File.join(Backup::LOG_PATH, 'backup.log'), 'a')

      Backup::Logger.message "This has been logged."
      Backup::Logger.error   "This has been logged."
      Backup::Logger.warn    "This has been logged."
      Backup::Logger.normal  "This has been logged."
    end
  end
end
