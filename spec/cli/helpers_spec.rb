# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::CLI::Helpers do
  let(:helpers) { Module.new.extend(Backup::CLI::Helpers) }

  describe '#run' do
    let(:stdin)   { mock }
    let(:stdout)  { mock }
    let(:stderr)  { mock }
    let(:process_status) { mock }

    it 'should run the given command using POpen4' do
      Open4.expects(:popen4).with('/path/to/command args').
        returns([123, stdin, stdout, stderr])
      Process.expects(:waitpid2).with(123).returns([123, process_status])
      stdout.expects(:read).returns('stdout message')
      stderr.expects(:read).returns('stderr message')

      helpers.expects(:command_name).with('/path/to/command args').
          returns('command')
      helpers.expects(:raise_if_command_failed!).with(
        'command',
        {:status => process_status,
         :stdout => 'stdout message',
         :stderr => 'stderr message',
         :ignore_exit_codes => [0]}
      )

      helpers.run('/path/to/command args').should == 'stdout message'
    end

    it 'should accept ignore_exit_codes and add 0 to the list' do
      Open4.expects(:popen4).with('/path/to/command args').
        returns([123, stdin, stdout, stderr])
      Process.expects(:waitpid2).with(123).returns([123, process_status])
      stdout.expects(:read).returns('stdout message')
      stderr.expects(:read).returns('stderr message')

      helpers.expects(:command_name).with('/path/to/command args').
          returns('command')
      helpers.expects(:raise_if_command_failed!).with(
        'command',
        {:status => process_status,
         :stdout => 'stdout message',
         :stderr => 'stderr message',
         :ignore_exit_codes => [1, 2, 0]}
      )

      helpers.run(
        '/path/to/command args', :ignore_exit_codes => [1, 2]
      ).should == 'stdout message'
    end
  end

  describe '#utility' do
    context 'when a system path for the utility is available' do
      it 'should return the system path with newline removed' do
        helpers.expects(:`).with('which foo 2>/dev/null').returns("system_path\n")
        helpers.utility(:foo).should == 'system_path'
      end

      it 'should cache the returned path' do
        helpers.expects(:`).once.with('which cache_me 2>/dev/null').
            returns("cached_path\n")

        helpers.utility(:cache_me).should == 'cached_path'
        helpers.utility(:cache_me).should == 'cached_path'
      end

      it 'should cache the value for all extended objects' do
        helpers.expects(:`).once.with('which once_only 2>/dev/null').
            returns("cached_path\n")

        helpers.utility(:once_only).should == 'cached_path'
        Class.new.extend(Backup::CLI::Helpers).utility(:once_only).
            should == 'cached_path'
      end
    end


    context 'when a system path for the utility is not available' do
      it 'should raise an error' do
        helpers.expects(:`).with('which unknown 2>/dev/null').returns("\n")

        expect do
          helpers.utility(:unknown)
        end.to raise_error(Backup::Errors::CLI::UtilityNotFoundError) {|err|
          err.message.should match(/Path to 'unknown' could not be found/)
        }
      end

      it 'should not cache any value for the utility' do
        helpers.expects(:`).with('which not_cached 2>/dev/null').twice.returns("\n")

        expect do
          helpers.utility(:not_cached)
        end.to raise_error(Backup::Errors::CLI::UtilityNotFoundError) {|err|
          err.message.should match(/Path to 'not_cached' could not be found/)
        }

        expect do
          helpers.utility(:not_cached)
        end.to raise_error(Backup::Errors::CLI::UtilityNotFoundError) {|err|
          err.message.should match(/Path to 'not_cached' could not be found/)
        }
      end
    end
  end # describe '#utility'

  describe '#command_name' do
    context 'given a command line path with no arguments' do
      it 'should return the base command name' do
        cmd = '/path/to/a/command'
        helpers.command_name(cmd).should == 'command'
      end
    end

    context 'given a command line path with a single argument' do
      it 'should return the base command name' do
        cmd = '/path/to/a/command with_args'
        helpers.command_name(cmd).should == 'command'
      end
    end

    context 'given a command line path with multiple arguments' do
      it 'should return the base command name' do
        cmd = '/path/to/a/command with multiple args'
        helpers.command_name(cmd).should == 'command'
      end
    end

    context 'given a command with no path and arguments' do
      it 'should return the base command name' do
        cmd = 'command args'
        helpers.command_name(cmd).should == 'command'
      end
    end

    context 'given a command with no path and no arguments' do
      it 'should return the base command name' do
        cmd = 'command'
        helpers.command_name(cmd).should == 'command'
      end
    end
  end # describe '#command_name'

  describe '#raise_if_command_failed!' do

    it 'returns nil if status exit code is in ignore_exit_codes' do
      process_data = { :status => '3', :ignore_exit_codes => [1,3,5] }
      helpers.raise_if_command_failed!('foo', process_data).should be_nil
    end

    it 'raises an error with stdout/stderr data' do
      process_data = { :status => '3', :ignore_exit_codes => [2,4,6],
                       :stdout => 'stdout data', :stderr => 'stderr data' }

      expect do
        helpers.raise_if_command_failed!('utility_name', process_data)
      end.to raise_error(
        Backup::Errors::CLI::SystemCallError,
        "CLI::SystemCallError: Failed to run utility_name on #{RUBY_PLATFORM}\n" +
        "  The following information should help to determine the problem:\n" +
        "  Exit Code: 3\n" +
        "  STDERR:\n" +
        "  stderr data\n" +
        "  STDOUT:\n" +
        "  stdout data"
      )
    end

  end

end
