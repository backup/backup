# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'
require 'timecop'

describe Backup::Logger do
  before do
    Timecop.freeze( Time.now )
  end

  context 'when logging regular messages' do
    it do
      Backup::Logger.expects(:puts).with("[#{ Time.now.strftime("%Y/%m/%d %H:%M:%S") }][\e[32mmessage\e[0m] This has been logged.")
      File.expects(:open).with(File.join(Backup::LOG_PATH, 'backup.log'), 'a')

      Backup::Logger.message "This has been logged."
    end
  end

  context 'when logging error messages' do
    it do
      Backup::Logger.expects(:puts).with("[#{ Time.now.strftime("%Y/%m/%d %H:%M:%S") }][\e[31merror\e[0m] This has been logged.")
      File.expects(:open).with(File.join(Backup::LOG_PATH, 'backup.log'), 'a')

      Backup::Logger.error "This has been logged."
    end
  end

  context 'when logging warn messages' do
    it do
      Backup::Logger.expects(:puts).with("[#{ Time.now.strftime("%Y/%m/%d %H:%M:%S") }][\e[33mwarning\e[0m] This has been logged.")
      File.expects(:open).with(File.join(Backup::LOG_PATH, 'backup.log'), 'a')

      Backup::Logger.warn "This has been logged."
    end
  end

  context 'when logging silent messages' do
    it do
      Backup::Logger.expects(:puts).never
      File.expects(:open).with(File.join(Backup::LOG_PATH, 'backup.log'), 'a')

      Backup::Logger.silent "This has been logged."
    end
  end
end
