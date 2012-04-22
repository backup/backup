# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe Backup::Logger do
  let(:logger_time)  { Time.now.strftime("%Y/%m/%d %H:%M:%S") }
  let(:logfile_path) { File.join(Backup::Config.log_path, 'backup.log') }
  let(:logfile_mock) { mock }
  let(:s) { sequence '' }

  before do
    Timecop.freeze(Time.now)

    # stubbed in spec_helper
    [:message, :error, :warn, :normal, :silent].each do |message_type|
      subject.unstub(message_type)
    end

    subject.quiet = nil
    subject.send(:remove_instance_variable, :@messages) rescue nil
    subject.send(:remove_instance_variable, :@has_warnings) rescue nil
  end

  describe '#message' do
    it 'sends a regular message to the console and log file' do
      subject.expects(:loggify).in_sequence(s).
          with('regular message', :message, :green).
          returns(:green_regular_message)
      subject.expects(:to_console).in_sequence(s).
          with(:green_regular_message)
      subject.expects(:loggify).in_sequence(s).
          with('regular message', :message).
          returns(:uncolored_regular_message)
      subject.expects(:to_file).in_sequence(s).
          with(:uncolored_regular_message)

      subject.message('regular message')
    end
  end

  describe '#error' do
    it 'sends an error message to the console (stderr) and log file' do
      subject.expects(:loggify).in_sequence(s).
          with('error message', :error, :red).
          returns(:red_error_message)
      subject.expects(:to_console).in_sequence(s).
          with(:red_error_message, true)
      subject.expects(:loggify).in_sequence(s).
          with('error message', :error).
          returns(:uncolored_error_message)
      subject.expects(:to_file).in_sequence(s).
          with(:uncolored_error_message)

      subject.error('error message')
    end
  end

  describe '#warn' do
    it 'sends a warning message to the console (stderr) and log file' do
      subject.expects(:loggify).in_sequence(s).
          with('warning message', :warning, :yellow).
          returns(:yellow_warning_message)
      subject.expects(:to_console).in_sequence(s).
          with(:yellow_warning_message, true)
      subject.expects(:loggify).in_sequence(s).
          with('warning message', :warning).
          returns(:uncolored_warning_message)
      subject.expects(:to_file).in_sequence(s).
          with(:uncolored_warning_message)

      subject.warn('warning message')
    end

    it 'sets has_warnings? to true' do
      subject.stubs(:to_console)
      subject.stubs(:to_file)
      expect { subject.warn('warning') }.to
          change{ subject.has_warnings? }.from(false).to(true)
    end
  end

  describe '#normal' do
    it 'sends a normal, unformatted message to the console and log file' do
      subject.expects(:loggify).in_sequence(s).
          with('normal message').
          returns(:unformatted_message)
      subject.expects(:to_console).in_sequence(s).
          with(:unformatted_message)
      subject.expects(:loggify).in_sequence(s).
          with('normal message').
          returns(:unformatted_message)
      subject.expects(:to_file).in_sequence(s).
          with(:unformatted_message)

      subject.normal('normal message')
    end
  end

  describe '#silent' do
    it 'sends a silent message to the log file' do
      subject.expects(:to_console).never
      subject.expects(:loggify).in_sequence(s).
          with('silent message', :silent).
          returns(:silent_message)
      subject.expects(:to_file).in_sequence(s).
          with(:silent_message)

      subject.silent('silent message')
    end
  end

  describe '#messages' do

    it 'returns an empty array if no messages have been sent' do
      subject.messages.should == []
    end

    it 'returns an array of all lines sent to the log file' do
      File.stubs(:open).yields(stub(:puts))
      strings = ['an array', 'of message', 'strings']
      subject.send(:to_file, strings)
      subject.messages.should == strings
    end

    it 'does not track lines sent to the console' do
      subject.stubs(:puts)
      strings = ['an array', 'of message', 'strings']
      subject.send(:to_console, strings)
      subject.messages.should == []
    end

  end # describe '#messages'

  describe '#clear!' do
    it 'should clear the log and reset has_warnings?' do
      subject.messages << 'foo'
      subject.instance_variable_set(:@has_warnings, true)
      subject.messages.count.should == 1
      subject.has_warnings?.should be_true

      subject.clear!
      subject.messages.should be_empty
      subject.has_warnings?.should be_false
    end
  end # describe '#clear!'

  describe '#truncate!' do
    context 'when log file does not exist' do
      before { File.stubs(:exist?).returns(false) }
      it 'should do nothing' do
        File.expects(:stat).never
        subject.truncate!
      end
    end

    context 'when log file is <= max_bytes' do
      before { File.stubs(:exist?).returns(true) }
      it 'should do nothing' do
        stat = mock
        File.expects(:stat).twice.with(
          File.join(Backup::Config.log_path, 'backup.log')
        ).returns(stat)

        [1, 2].each do |size|
          stat.expects(:size).returns(size)

          FileUtils.expects(:mv).never
          File.expects(:open).never
          FileUtils.expects(:rm_f).never

          subject.truncate!(2)
        end
      end
    end

    context 'when log file is > max_bytes' do
      before do
        FileUtils.unstub(:mkdir_p)
        FileUtils.unstub(:mv)
        FileUtils.unstub(:rm)
        FileUtils.unstub(:rm_f)
      end

      after do
        Backup::Config.send(:reset!)
      end

      it 'should truncate the file, removing older lines' do
        max_bytes = 5_000
        line_len  = 120
        Dir.mktmpdir do |dir|
          Backup::Config.update(:root_path => dir)
          FileUtils.mkdir_p(Backup::Config.log_path)
          log_file = File.join(Backup::Config.log_path, 'backup.log')

          lineno = 0
          over_max = (max_bytes * 1.25).to_i
          File.open(log_file, 'w') do |f|
            until f.pos > over_max
              f.puts "#{ lineno += 1 }: ".ljust(line_len, 'x')
            end
          end
          File.stat(log_file).size.
              should be_within(line_len + 2).of(over_max)

          subject.truncate!(max_bytes)

          File.stat(log_file).size.
              should be_within(line_len + 2).of(max_bytes)

          File.readlines(log_file).last.chomp.
              should == "#{ lineno }: ".ljust(line_len, 'x')

          File.exist?(log_file + '~').should be_false
        end
      end
    end

  end # describe '#truncate!'

  describe '#loggify' do

    it 'returns an array of strings split on newline separators' do
      str_aa = "first line\nsecond line"
      str_ab = "first line\nsecond line\n"
      expected_a = ["[#{logger_time}][msg_type] first line",
                  "[#{logger_time}][msg_type] second line"]

      str_b = 'string with no newline'
      expected_b = ["[#{logger_time}][msg_type] string with no newline"]

      subject.send(:loggify, str_aa, :msg_type).should == expected_a
      subject.send(:loggify, str_ab, :msg_type).should == expected_a
      subject.send(:loggify, str_b,  :msg_type).should == expected_b
    end

    it 'formats a string with color if color is given' do
      green_type  = ["[#{logger_time}][#{"\e[32mmsg_type\e[0m"}] foo"]
      yellow_type = ["[#{logger_time}][#{"\e[33mmsg_type\e[0m"}] foo"]
      red_type    = ["[#{logger_time}][#{"\e[31mmsg_type\e[0m"}] foo"]

      subject.send(:loggify, 'foo', :msg_type, :green ).should == green_type
      subject.send(:loggify, 'foo', :msg_type, :yellow).should == yellow_type
      subject.send(:loggify, 'foo', :msg_type, :red   ).should == red_type
    end

    it 'does not colorize if no color given' do
      no_color = ["[#{logger_time}][msg_type] foo"]
      subject.send(:loggify, 'foo', :msg_type).should == no_color
    end

    it 'accepts blank lines in the message' do
      str = "first line\n\nthird line"
      expected = ["[#{logger_time}][msg_type] first line",
                  "[#{logger_time}][msg_type] ",
                  "[#{logger_time}][msg_type] third line"]

      subject.send(:loggify, str, :msg_type).should == expected
    end

    it 'accepts an object responding to #to_s for the message' do
      obj = StandardError.new("first line\nsecond line")
      expected = ["[#{logger_time}][msg_type] first line",
                  "[#{logger_time}][msg_type] second line"]

      subject.send(:loggify, obj, :msg_type).should == expected
    end

    it 'returns an unformatted lines if type is not given' do
      str_a = 'single line'
      str_b = "first line\n\nthird line"
      expected_a = ['single line']
      expected_b = ['first line', '', 'third line']

      subject.send(:loggify, str_a).should == expected_a
      subject.send(:loggify, str_b).should == expected_b
    end

  end # describe '#loggify'

  describe '#to_console' do

    context 'when +stderr+ is not set (false)' do
      it 'writes an array of strings to stdout' do
        lines = [ 'line one', 'line two', 'line three']
        lines.each {|line| subject.expects(:puts).with(line).in_sequence(s) }
        subject.send(:to_console, lines)
      end
    end

    context 'when +stderr+ is set (true)' do
      it 'writes an array of strings to stdout' do
        lines = [ 'line one', 'line two', 'line three']
        lines.each {|line| Kernel.expects(:warn).with(line).in_sequence(s) }
        subject.send(:to_console, lines, true)
      end
    end

    it 'returns nil if quiet? is true' do
      subject.quiet = true
      subject.expects(:puts).never
      subject.send(:to_console, 'a string')
    end

  end # describe '#to_console'

  describe '#to_file' do

    it 'writes an array of strings to the log file' do
      lines = ['line one', 'line two', 'line three']
      File.stubs(:open).yields(logfile_mock)
      lines.each {|line| logfile_mock.expects(:puts).with(line).in_sequence(s) }
      subject.send(:to_file, lines)
    end

    it 'appends each line written to #messages' do
      lines = ['line one', 'line two', 'line three']
      File.stubs(:open)
      a_mock = mock
      subject.expects(:messages).returns(a_mock)
      a_mock.expects(:push).with('line one', 'line two', 'line three')
      subject.send(:to_file, lines)
    end

    it 'only opens the log file once to append multiple lines' do
      lines = ['line one', 'line two', 'line three']
      File.expects(:open).once.with(logfile_path, 'a').yields(logfile_mock)
      logfile_mock.expects(:puts).times(3)
      subject.send(:to_file, lines)
    end

  end # describe '#to_file'

  describe 'color methods' do

    it 'color methods send strings to #colorize with color codes' do
      colors = [ [:green, 32], [:yellow, 33], [:red, 31] ]
      colors.each do |color, code|
        subject.expects(:colorize).with('foo', code).in_sequence(s)
      end
      colors.each {|color, code| subject.send(color, 'foo') }
    end

    it '#colorize adds the code to the string' do
      [32, 33, 31].each do |code|
        subject.send(:colorize, 'foo', code).
            should == "\e[#{code}mfoo\e[0m"
      end
    end

  end # color methods

  describe '#quiet' do
    it 'should be nil by default' do
      # of course, 'before' is setting it to nil ;)
      subject.quiet.should be_nil
    end

    it 'can be set true/false' do
      subject.quiet = true
      subject.quiet.should be_true
      subject.quiet = false
      subject.quiet.should be_false
    end
  end

end
