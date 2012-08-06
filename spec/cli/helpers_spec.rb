# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::CLI::Helpers do
  let(:helpers) { Module.new.extend(Backup::CLI::Helpers) }

  describe '#run' do
    let(:stdout_io) { stub(:read => stdout_messages) }
    let(:stderr_io) { stub(:read => stderr_messages) }
    let(:stdin_io)  { stub(:close) }
    let(:process_status) { stub(:success? => process_success) }
    let(:command) { '/path/to/cmd_name arg1 arg2' }

    context 'when the command is successful' do
      let(:process_success) { true }

      before do
        Backup::Logger.expects(:message).with(
          "Running system utility 'cmd_name'..."
        )

        Open4.expects(:popen4).with(command).yields(
          nil, stdin_io, stdout_io, stderr_io
        ).returns(process_status)
      end

      context 'and generates no messages' do
        let(:stdout_messages) { '' }
        let(:stderr_messages) { '' }

        it 'should return stdout and generate no additional log messages' do
          helpers.send(:run, command).should == ''
        end
      end

      context 'and generates only stdout messages' do
        let(:stdout_messages) { "out line1\nout line2\n" }
        let(:stderr_messages) { '' }

        it 'should return stdout and log the stdout messages' do
          Backup::Logger.expects(:message).with(
            "cmd_name:STDOUT: out line1\ncmd_name:STDOUT: out line2"
          )
          helpers.send(:run, command).should == stdout_messages.strip
        end
      end

      context 'and generates only stderr messages' do
        let(:stdout_messages) { '' }
        let(:stderr_messages) { "err line1\nerr line2\n" }

        it 'should return stdout and log the stderr messages' do
          Backup::Logger.expects(:warn).with(
            "cmd_name:STDERR: err line1\ncmd_name:STDERR: err line2"
          )
          helpers.send(:run, command).should == ''
        end
      end

      context 'and generates messages on both stdout and stderr' do
        let(:stdout_messages) { "out line1\nout line2\n" }
        let(:stderr_messages) { "err line1\nerr line2\n" }

        it 'should return stdout and log both stdout and stderr messages' do
          Backup::Logger.expects(:message).with(
            "cmd_name:STDOUT: out line1\ncmd_name:STDOUT: out line2"
          )
          Backup::Logger.expects(:warn).with(
            "cmd_name:STDERR: err line1\ncmd_name:STDERR: err line2"
          )
          helpers.send(:run, command).should == stdout_messages.strip
        end
      end
    end # context 'when the command is successful'

    context 'when the command is not successful' do
      let(:process_success) { false }
      let(:message_head) do
        "CLI::SystemCallError: 'cmd_name' Failed on #{ RUBY_PLATFORM }\n" +
        "  The following information should help to determine the problem:\n" +
        "  Command was: /path/to/cmd_name arg1 arg2\n" +
        "  Exit Status: 1\n"
      end

      before do
        Backup::Logger.expects(:message).with(
          "Running system utility 'cmd_name'..."
        )

        Open4.expects(:popen4).with(command).yields(
          nil, stdin_io, stdout_io, stderr_io
        ).returns(process_status)

        process_status.stubs(:exitstatus).returns(1)
      end

      context 'and generates no messages' do
        let(:stdout_messages) { '' }
        let(:stderr_messages) { '' }

        it 'should raise an error reporting no messages' do
          expect do
            helpers.send(:run, command)
          end.to raise_error {|err|
            err.message.should == message_head +
              "  STDOUT Messages: None\n" +
              "  STDERR Messages: None"
          }
        end
      end

      context 'and generates only stdout messages' do
        let(:stdout_messages) { "out line1\nout line2\n" }
        let(:stderr_messages) { '' }

        it 'should raise an error and report the stdout messages' do
          expect do
            helpers.send(:run, command)
          end.to raise_error {|err|
            err.message.should == message_head +
              "  STDOUT Messages: \n" +
              "  out line1\n" +
              "  out line2\n" +
              "  STDERR Messages: None"
          }
        end
      end

      context 'and generates only stderr messages' do
        let(:stdout_messages) { '' }
        let(:stderr_messages) { "err line1\nerr line2\n" }

        it 'should raise an error and report the stderr messages' do
          expect do
            helpers.send(:run, command)
          end.to raise_error {|err|
            err.message.should == message_head +
              "  STDOUT Messages: None\n" +
              "  STDERR Messages: \n" +
              "  err line1\n" +
              "  err line2"
          }
        end
      end

      context 'and generates messages on both stdout and stderr' do
        let(:stdout_messages) { "out line1\nout line2\n" }
        let(:stderr_messages) { "err line1\nerr line2\n" }

        it 'should raise an error and report the stdout and stderr messages' do
          expect do
            helpers.send(:run, command)
          end.to raise_error {|err|
            err.message.should == message_head +
              "  STDOUT Messages: \n" +
              "  out line1\n" +
              "  out line2\n" +
              "  STDERR Messages: \n" +
              "  err line1\n" +
              "  err line2"
          }
        end
      end
    end # context 'when the command is not successful'

    context 'when the system fails to execute the command' do
      before do
        Backup::Logger.expects(:message).with(
          "Running system utility 'cmd_name'..."
        )

        Open4.expects(:popen4).raises("exec call failed")
      end

      it 'should raise an error wrapping the system error raised' do
        expect do
          helpers.send(:run, command)
        end.to raise_error {|err|
          err.message.should == "CLI::SystemCallError: " +
            "Failed to execute system command on #{ RUBY_PLATFORM }\n" +
            "  Command was: /path/to/cmd_name arg1 arg2\n" +
            "  Reason: RuntimeError\n" +
            "  exec call failed"
        }
      end
    end # context 'when the system fails to execute the command'
  end # describe '#run'

  describe '#utility' do
    after { Backup::CLI::Helpers::UTILITY.clear }

    context 'when a system path for the utility is available' do
      it 'should return the system path with newline removed' do
        helpers.expects(:`).with('which foo 2>/dev/null').returns("system_path\n")
        helpers.send(:utility, :foo).should == 'system_path'
      end

      it 'should cache the returned path' do
        helpers.expects(:`).once.with('which cache_me 2>/dev/null').
            returns("cached_path\n")

        helpers.send(:utility, :cache_me).should == 'cached_path'
        helpers.send(:utility, :cache_me).should == 'cached_path'
      end

      it 'should cache the value for all extended objects' do
        helpers.expects(:`).once.with('which once_only 2>/dev/null').
            returns("cached_path\n")

        helpers.send(:utility, :once_only).should == 'cached_path'
        Class.new.extend(Backup::CLI::Helpers).send(
            :utility, :once_only).should == 'cached_path'
      end
    end

    context 'when a system path for the utility is not available' do
      it 'should raise an error' do
        helpers.expects(:`).with('which unknown 2>/dev/null').returns("\n")

        expect do
          helpers.send(:utility, :unknown)
        end.to raise_error(Backup::Errors::CLI::UtilityNotFoundError) {|err|
          err.message.should match(/Could not locate 'unknown'/)
        }
      end

      it 'should not cache any value for the utility' do
        helpers.expects(:`).with('which not_cached 2>/dev/null').twice.returns("\n")

        expect do
          helpers.send(:utility, :not_cached)
        end.to raise_error(Backup::Errors::CLI::UtilityNotFoundError) {|err|
          err.message.should match(/Could not locate 'not_cached'/)
        }

        expect do
          helpers.send(:utility, :not_cached)
        end.to raise_error(Backup::Errors::CLI::UtilityNotFoundError) {|err|
          err.message.should match(/Could not locate 'not_cached'/)
        }
      end
    end

    it 'should raise an error if name is nil' do
      expect do
        helpers.send(:utility, nil)
      end.to raise_error(
        Backup::Errors::CLI::UtilityNotFoundError,
          'CLI::UtilityNotFoundError: Utility Name Empty'
      )
    end

    it 'should raise an error if name is empty' do
      expect do
        helpers.send(:utility, ' ')
      end.to raise_error(
        Backup::Errors::CLI::UtilityNotFoundError,
          'CLI::UtilityNotFoundError: Utility Name Empty'
      )
    end
  end # describe '#utility'

  describe '#command_name' do
    context 'given a command line path with no arguments' do
      it 'should return the base command name' do
        cmd = '/path/to/a/command'
        helpers.send(:command_name, cmd).should == 'command'
      end
    end

    context 'given a command line path with a single argument' do
      it 'should return the base command name' do
        cmd = '/path/to/a/command with_args'
        helpers.send(:command_name, cmd).should == 'command'
      end
    end

    context 'given a command line path with multiple arguments' do
      it 'should return the base command name' do
        cmd = '/path/to/a/command with multiple args'
        helpers.send(:command_name, cmd).should == 'command'
      end
    end

    context 'given a command with no path and arguments' do
      it 'should return the base command name' do
        cmd = 'command args'
        helpers.send(:command_name, cmd).should == 'command'
      end
    end

    context 'given a command with no path and no arguments' do
      it 'should return the base command name' do
        cmd = 'command'
        helpers.send(:command_name, cmd).should == 'command'
      end
    end
  end # describe '#command_name'

end
