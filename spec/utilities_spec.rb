# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe Backup::Utilities do
  let(:utilities) { Backup::Utilities }
  let(:helpers) { Module.new.extend(Backup::Utilities::Helpers) }

  # Note: spec_helper resets Utilities before each example

  describe '.configure' do
    before do
      File.stubs(:executable?).returns(true)
      utilities.unstub(:gnu_tar?)
      utilities.unstub(:utility)

      utilities.configure do
        # General Utilites
        tar      '/path/to/tar'
        tar_dist :gnu   # or :bsd
        cat      '/path/to/cat'
        split    '/path/to/split'
        sudo     '/path/to/sudo'
        chown    '/path/to/chown'
        hostname '/path/to/hostname'

        # Compressors
        gzip    '/path/to/gzip'
        bzip2   '/path/to/bzip2'
        lzma    '/path/to/lzma'   # deprecated
        pbzip2  '/path/to/pbzip2' # deprecated

        # Database Utilities
        mongo       '/path/to/mongo'
        mongodump   '/path/to/mongodump'
        mysqldump   '/path/to/mysqldump'
        pg_dump     '/path/to/pg_dump'
        pg_dumpall  '/path/to/pg_dumpall'
        redis_cli   '/path/to/redis-cli'
        riak_admin  '/path/to/riak-admin'

        # Encryptors
        gpg     '/path/to/gpg'
        openssl '/path/to/openssl'

        # Syncer and Storage
        rsync   '/path/to/rsync'
        ssh     '/path/to/ssh'

        # Notifiers
        sendmail  '/path/to/sendmail'
        exim      '/path/to/exim'
        send_nsca '/path/to/send_nsca'
      end
    end

    it 'allows utilities to be configured' do
      utilities::NAMES.each do |name|
        helpers.send(:utility, name).should == "/path/to/#{ name }"
      end
    end

    it 'presets gnu_tar? value to true' do
      utilities.expects(:run).never
      utilities.gnu_tar?.should be(true)
      helpers.send(:gnu_tar?).should be(true)
    end

    it 'presets gnu_tar? value to false' do
      utilities.configure do
        tar_dist :bsd
      end

      utilities.expects(:run).never
      utilities.gnu_tar?.should be(false)
      helpers.send(:gnu_tar?).should be(false)
    end

    it 'expands relative paths' do
      utilities.configure do
        tar 'my_tar'
      end
      path = File.expand_path('my_tar')
      utilities::UTILITY['tar'].should == path
      helpers.send(:utility, :tar).should == path
    end

    it 'raises Error if utility is not found or executable' do
      File.stubs(:executable?).returns(false)
      expect do
        utilities.configure do
          tar 'not_found'
        end
      end.to raise_error(Backup::Utilities::Error)
    end
  end # describe '.configure'

  describe '.gnu_tar?' do
    before do
      utilities.unstub(:gnu_tar?)
    end

    it 'determines when tar is GNU tar' do
      utilities.expects(:utility).with(:tar).returns('tar')
      utilities.expects(:run).with('tar --version').returns(
        'tar (GNU tar) 1.26\nCopyright (C) 2011 Free Software Foundation, Inc.'
      )
      utilities.gnu_tar?.should be(true)
      utilities.instance_variable_get(:@gnu_tar).should be(true)
    end

    it 'determines when tar is BSD tar' do
      utilities.expects(:utility).with(:tar).returns('tar')
      utilities.expects(:run).with('tar --version').returns(
        'bsdtar 3.0.4 - libarchive 3.0.4'
      )
      utilities.gnu_tar?.should be(false)
      utilities.instance_variable_get(:@gnu_tar).should be(false)
    end

    it 'returns cached true value' do
      utilities.instance_variable_set(:@gnu_tar, true)
      utilities.expects(:run).never
      utilities.gnu_tar?.should be(true)
    end

    it 'returns cached false value' do
      utilities.instance_variable_set(:@gnu_tar, false)
      utilities.expects(:run).never
      utilities.gnu_tar?.should be(false)
    end
  end

end # describe Backup::Utilities

describe Backup::Utilities::Helpers do
  let(:helpers) { Module.new.extend(Backup::Utilities::Helpers) }
  let(:utilities) { Backup::Utilities }

  describe '#utility' do
    before do
      utilities.unstub(:utility)
    end

    context 'when a system path for the utility is available' do
      it 'should return the system path with newline removed' do
        utilities.expects(:`).with("which 'foo' 2>/dev/null").returns("system_path\n")
        helpers.send(:utility, :foo).should == 'system_path'
      end

      it 'should cache the returned path' do
        utilities.expects(:`).once.with("which 'cache_me' 2>/dev/null").
            returns("cached_path\n")

        helpers.send(:utility, :cache_me).should == 'cached_path'
        helpers.send(:utility, :cache_me).should == 'cached_path'
      end

      it 'should return a mutable copy of the path' do
        utilities.expects(:`).once.with("which 'cache_me' 2>/dev/null").
            returns("cached_path\n")

        helpers.send(:utility, :cache_me) << 'foo'
        helpers.send(:utility, :cache_me).should == 'cached_path'
      end

      it 'should cache the value for all extended objects' do
        utilities.expects(:`).once.with("which 'once_only' 2>/dev/null").
            returns("cached_path\n")

        helpers.send(:utility, :once_only).should == 'cached_path'
        Class.new.extend(Backup::Utilities::Helpers).send(
            :utility, :once_only).should == 'cached_path'
      end
    end

    it 'should raise an error if the utiilty is not found' do
      utilities.expects(:`).with("which 'unknown' 2>/dev/null").returns("\n")

      expect do
        helpers.send(:utility, :unknown)
      end.to raise_error(Backup::Utilities::Error) {|err|
        err.message.should match(/Could not locate 'unknown'/)
      }
    end

    it 'should raise an error if name is nil' do
      utilities.expects(:`).never
      expect do
        helpers.send(:utility, nil)
      end.to raise_error(
        Backup::Utilities::Error, 'Utilities::Error: Utility Name Empty'
      )
    end

    it 'should raise an error if name is empty' do
      utilities.expects(:`).never
      expect do
        helpers.send(:utility, ' ')
      end.to raise_error(
        Backup::Utilities::Error, 'Utilities::Error: Utility Name Empty'
      )
    end
  end # describe '#utility'

  describe '#command_name' do
    it 'returns the base command name' do
      cmd = '/path/to/a/command'
      expect( helpers.send(:command_name, cmd) ).to eq 'command'

      cmd = '/path/to/a/command with_args'
      expect( helpers.send(:command_name, cmd) ).to eq 'command'

      cmd = '/path/to/a/command with multiple args'
      expect( helpers.send(:command_name, cmd) ).to eq 'command'

      # should not happen, but should handle it
      cmd = 'command args'
      expect( helpers.send(:command_name, cmd) ).to eq 'command'
      cmd = 'command'
      expect( helpers.send(:command_name, cmd) ).to eq 'command'
    end

    it 'returns command name run with sudo' do
      cmd = '/path/to/sudo -n /path/to/command args'
      expect( helpers.send(:command_name, cmd) ).
          to eq 'sudo -n command'

      cmd = '/path/to/sudo -n -u username /path/to/command args'
      expect( helpers.send(:command_name, cmd) ).
          to eq 'sudo -n -u username command'

      # should not happen, but should handle it
      cmd = '/path/to/sudo -n -u username command args'
      expect( helpers.send(:command_name, cmd) ).
          to eq 'sudo -n -u username command args'
    end

    it 'strips environment variables' do
      cmd = "FOO='bar' BAR=foo /path/to/a/command with_args"
      expect( helpers.send(:command_name, cmd) ).to eq 'command'
    end
  end # describe '#command_name'

  describe '#run' do
    let(:stdout_io) { stub(:read => stdout_messages) }
    let(:stderr_io) { stub(:read => stderr_messages) }
    let(:stdin_io)  { stub(:close) }
    let(:process_status) { stub(:success? => process_success) }
    let(:command) { '/path/to/cmd_name arg1 arg2' }

    before do
      utilities.unstub(:run)
    end

    context 'when the command is successful' do
      let(:process_success) { true }

      before do
        Backup::Logger.expects(:info).with(
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
          Backup::Logger.expects(:info).with(
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
          Backup::Logger.expects(:info).with(
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
        "Utilities::Error: 'cmd_name' failed with exit status: 1\n"
      end

      before do
        Backup::Logger.expects(:info).with(
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
        Backup::Logger.expects(:info).with(
          "Running system utility 'cmd_name'..."
        )

        Open4.expects(:popen4).raises("exec call failed")
      end

      it 'should raise an error wrapping the system error raised' do
        expect do
          helpers.send(:run, command)
        end.to raise_error(Backup::Utilities::Error) {|err|
          err.message.should match("Failed to execute 'cmd_name'")
          err.message.should match('RuntimeError: exec call failed')
        }
      end
    end # context 'when the system fails to execute the command'
  end # describe '#run'

  describe 'gnu_tar?' do
    it 'returns true if tar_dist is gnu' do
      Backup::Utilities.stubs(:gnu_tar?).returns(true)
      helpers.send(:gnu_tar?).should be(true)
    end

    it 'returns false if tar_dist is bsd' do
      Backup::Utilities.stubs(:gnu_tar?).returns(false)
      helpers.send(:gnu_tar?).should be(false)
    end
  end
end # describe Backup::Utilities::Helpers
