# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)
require 'timecop'

describe Backup::Logger do
  let(:logger_time)  { Time.now.strftime("%Y/%m/%d %H:%M:%S") }
  let(:log_message)  { 'This has been logged.' }
  let(:logfile_path) { File.join(Backup::LOG_PATH, 'backup.log') }
  let(:logfile) { mock }

  before do
    Timecop.freeze(Time.now)

    # stubbed in spec_helper
    [:message, :error, :warn, :normal, :silent].each do |message_type|
      Backup::Logger.unstub(message_type)
    end

    Backup::Logger.send(:remove_const, :QUIET) rescue nil
    Backup::Logger.send(:remove_instance_variable, :@messages) rescue nil
    Backup::Logger.send(:remove_instance_variable, :@has_warnings) rescue nil
  end

  describe '#message' do
    let(:plain_message) { "[#{logger_time}][message] #{log_message}" }
    let(:green_message) { "[#{logger_time}][\e[32mmessage\e[0m] #{log_message}" }

    before do
      # it always writes the message to the log file
      File.expects(:open).with(logfile_path, 'a').yields(logfile)
      logfile.expects(:write).with("#{plain_message}\n")
    end

    context 'in normal mode' do
      it 'outputs to STDOUT with time and a `green` indicator' do
        Backup::Logger.expects(:puts).with(green_message)
        Backup::Logger.message log_message
      end
    end

    context 'in `quiet` mode' do
      before { Backup::Logger.send(:const_set, :QUIET, true) }

      it 'only writes to the log file' do
        Backup::Logger.expects(:puts).never
        Backup::Logger.message log_message
      end
    end

    after do
      # it always stores the logged message
      Backup::Logger.messages.should == [plain_message]
      # it never indicates a warning
      Backup::Logger.has_warnings?.should == false
    end
  end

  describe '#error' do
    let(:plain_error) { "[#{logger_time}][error] #{log_message}" }
    let(:red_error)   { "[#{logger_time}][\e[31merror\e[0m] #{log_message}" }

    before do
      # it always writes the message to the log file
      File.expects(:open).with(logfile_path, 'a').yields(logfile)
      logfile.expects(:write).with("#{plain_error}\n")
    end

    context 'when logging normally' do
      it 'outputs to STDOUT with time and a `red` indicator and writes it to the log file' do
        Backup::Logger.expects(:puts).with(red_error)
        Backup::Logger.error log_message
      end
    end

    context 'when logging in `quiet` mode' do
      before { Backup::Logger.send(:const_set, :QUIET, true) }

      it 'only writes to the log file' do
        Backup::Logger.expects(:puts).never
        Backup::Logger.error log_message
      end
    end

    after do
      # it always stores the logged message
      Backup::Logger.messages.should == [plain_error]
      # it never indicates a warning
      Backup::Logger.has_warnings?.should == false
    end
  end

  describe '#warn' do
    let(:plain_warning)  { "[#{logger_time}][warning] #{log_message}" }
    let(:yellow_warning) { "[#{logger_time}][\e[33mwarning\e[0m] #{log_message}" }

    before do
      # it always writes the message to the log file
      File.expects(:open).with(logfile_path, 'a').yields(logfile)
      logfile.expects(:write).with("#{plain_warning}\n")
    end

    context 'when logging normally' do
      it 'outputs to STDOUT with time and a `yellow` indicator and writes it to the log file' do
        Backup::Logger.expects(:puts).with(yellow_warning)
        Backup::Logger.warn log_message
      end
    end

    context 'when logging in `quiet` mode' do
      before { Backup::Logger.send(:const_set, :QUIET, true) }

      it 'only writes to the log file' do
        Backup::Logger.expects(:puts).never
        Backup::Logger.warn log_message
      end
    end

    after do
      # it always stores the logged message
      Backup::Logger.messages.should == [plain_warning]
      # it always indicates a warning
      Backup::Logger.has_warnings?.should == true
    end
  end

  describe '#normal' do
    let(:normal_message)  { log_message }

    before do
      # it always writes the message to the log file
      File.expects(:open).with(logfile_path, 'a').yields(logfile)
      logfile.expects(:write).with("#{normal_message}\n")
    end

    context 'when logging normally' do
      it 'outputs the given string to STDOUT with no changes and writes it to the log file' do
        Backup::Logger.expects(:puts).with(normal_message)
        Backup::Logger.normal log_message
      end
    end

    context 'when logging in `quiet` mode' do
      before { Backup::Logger.send(:const_set, :QUIET, true) }

      it 'only writes to the log file' do
        Backup::Logger.expects(:puts).never
        Backup::Logger.normal log_message
      end
    end

    after do
      # it always stores the logged message
      Backup::Logger.messages.should == [normal_message]
      # it never indicates a warning
      Backup::Logger.has_warnings?.should == false
    end
  end

  describe '#silent' do
    let(:silent_message) { "[#{logger_time}][silent] #{log_message}" }

    before do
      # it always writes the message to the log file
      File.expects(:open).with(logfile_path, 'a').yields(logfile)
      logfile.expects(:write).with("#{silent_message}\n")
    end

    context 'when logging normally' do
      it 'only writes to the log file' do
        Backup::Logger.expects(:puts).never
        Backup::Logger.silent log_message
      end
    end

    context 'when logging in `quiet` mode' do
      before { Backup::Logger.send(:const_set, :QUIET, true) }

      it 'only writes to the log file' do
        Backup::Logger.expects(:puts).never
        Backup::Logger.silent log_message
      end
    end

    after do
      # it always stores the logged message
      Backup::Logger.messages.should == [silent_message]
      # it never indicates a warning
      Backup::Logger.has_warnings?.should == false
    end
  end

end
