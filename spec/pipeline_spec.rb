# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe 'Backup::Pipeline' do
  let(:pipeline)  { Backup::Pipeline.new }

  it 'should include Utilities::Helpers' do
    Backup::Pipeline.
        include?(Backup::Utilities::Helpers).should be_true
  end

  describe '#initialize' do
    it 'should create a new pipeline' do
      pipeline.instance_variable_get(:@commands).should == []
      pipeline.instance_variable_get(:@success_codes).should == []
      pipeline.errors.should == []
      pipeline.stderr.should == ''
    end
  end

  describe '#add' do
    it 'should add a command with the given successful exit codes' do
      pipeline.add 'a command', [0]
      pipeline.instance_variable_get(:@commands).should == ['a command']
      pipeline.instance_variable_get(:@success_codes).should == [[0]]

      pipeline.add 'another command', [1, 3]
      pipeline.instance_variable_get(:@commands).
          should == ['a command', 'another command']
      pipeline.instance_variable_get(:@success_codes).
          should == [[0],[1, 3]]
    end
  end

  describe '#<<' do
    it 'should add a command with the default successful exit code (0)' do
      pipeline.expects(:add).with('a command', [0])
      pipeline << 'a command'
    end
  end

  describe '#run' do
    let(:stdout) { mock }
    let(:stderr) { mock }

    before do
      Backup::Pipeline.any_instance.unstub(:run)
      pipeline.expects(:pipeline).returns('foo')
      # stub Utilities::Helpers#command_name so it simply returns what it's passed
      pipeline.class.send(:define_method, :command_name, lambda {|arg| arg } )
    end

    context 'when pipeline command is successfully executed' do
      before do
        Open4.expects(:popen4).with('foo').yields(nil, nil, stdout, stderr)
      end

      context 'when all commands within the pipeline are successful' do
        before do
          pipeline.instance_variable_set(:@success_codes, [[0],[0,3]])
          stdout.expects(:read).returns("0|0:1|3:\n")
        end

        context 'when commands output no stderr messages' do
          before do
            stderr.expects(:read).returns('')
            pipeline.stubs(:stderr_messages).returns(false)
          end

          it 'should process the returned stdout/stderr and report no errors' do
            Backup::Logger.expects(:warn).never

            pipeline.run
            pipeline.stderr.should == ''
            pipeline.errors.should == []
          end
        end

        context 'when successful commands output messages on stderr' do
          before do
            stderr.expects(:read).returns("stderr output\n")
            pipeline.stubs(:stderr_messages).returns('stderr_messages_output')
          end

          it 'should log a warning with the stderr messages' do
            Backup::Logger.expects(:warn).with('stderr_messages_output')

            pipeline.run
            pipeline.stderr.should == 'stderr output'
            pipeline.errors.should == []
          end
        end
      end # context 'when all commands within the pipeline are successful'

      context 'when commands within the pipeline are not successful' do
        before do
          pipeline.instance_variable_set(:@commands, ['first', 'second', 'third'])
          pipeline.instance_variable_set(:@success_codes, [[0,1],[0,3],[0]])
          stderr.expects(:read).returns("stderr output\n")
          pipeline.stubs(:stderr_messages).returns('success? should be false')
        end

        context 'when the commands return in sequence' do
          before do
            stdout.expects(:read).returns("0|1:1|1:2|0:\n")
          end

          it 'should set @errors and @stderr without logging warnings' do
            Backup::Logger.expects(:warn).never

            pipeline.run
            pipeline.stderr.should == 'stderr output'
            pipeline.errors.count.should be(1)
            pipeline.errors.first.should be_a_kind_of SystemCallError
            pipeline.errors.first.errno.should be(1)
            pipeline.errors.first.message.should match(
              "'second' returned exit code: 1"
            )
          end
        end # context 'when the commands return in sequence'

        context 'when the commands return out of sequence' do
          before do
            stdout.expects(:read).returns("1|3:2|4:0|1:\n")
          end

          it 'should properly associate the exitstatus for each command' do
            Backup::Logger.expects(:warn).never

            pipeline.run
            pipeline.stderr.should == 'stderr output'
            pipeline.errors.count.should be(1)
            pipeline.errors.first.should be_a_kind_of SystemCallError
            pipeline.errors.first.errno.should be(4)
            pipeline.errors.first.message.should match(
              "'third' returned exit code: 4"
            )
          end
        end # context 'when the commands return out of sequence'

        context 'when multiple commands fail (out of sequence)' do
          before do
            stdout.expects(:read).returns("1|1:2|0:0|3:\n")
          end

          it 'should properly associate the exitstatus for each command' do
            Backup::Logger.expects(:warn).never

            pipeline.run
            pipeline.stderr.should == 'stderr output'
            pipeline.errors.count.should be(2)
            pipeline.errors.each {|err| err.should be_a_kind_of SystemCallError }
            pipeline.errors[0].errno.should be(3)
            pipeline.errors[0].message.should match(
              "'first' returned exit code: 3"
            )
            pipeline.errors[1].errno.should be(1)
            pipeline.errors[1].message.should match(
              "'second' returned exit code: 1"
            )
          end
        end # context 'when the commands return (out of sequence)'

      end # context 'when commands within the pipeline are not successful'
    end # context 'when pipeline command is successfully executed'

    context 'when pipeline command fails to execute' do
      before do
        Open4.expects(:popen4).with('foo').raises('exec failed')
      end

      it 'should raise an error' do
        expect do
          pipeline.run
        end.to raise_error(Backup::Pipeline::Error) {|err|
          err.message.should eq(
            "Pipeline::Error: Pipeline failed to execute\n" +
            "--- Wrapped Exception ---\n" +
            "RuntimeError: exec failed"
          )
        }
      end
    end # context 'when pipeline command fails to execute'

  end # describe '#run'

  describe '#success?' do
    it 'returns true when @errors is empty' do
      pipeline.success?.should be_true
    end

    it 'returns false when @errors is not empty' do
      pipeline.instance_variable_set(:@errors, ['foo'])
      pipeline.success?.should be_false
    end
  end # describe '#success?'

  describe '#error_messages' do
    let(:sys_err) { RUBY_VERSION < '1.9' ? 'SystemCallError' : 'Errno::NOERROR' }

    before do
      # use 0 since others may be platform-dependent
      pipeline.instance_variable_set(
        :@errors, [
          SystemCallError.new('first error', 0),
          SystemCallError.new('second error', 0)
        ]
      )
    end

    context 'when #stderr_messages has messages' do
      before do
        pipeline.expects(:stderr_messages).returns("stderr messages\n")
      end

      it 'should output #stderr_messages and formatted system error messages' do
        pipeline.error_messages.should match(/
          stderr\smessages\n
          The\sfollowing\ssystem\serrors\swere\sreturned:\n
          #{ sys_err }:\s(.*?)\sfirst\serror\n
          #{ sys_err }:\s(.*?)\ssecond\serror
        /x)
      end
    end

    context 'when #stderr_messages has no messages' do
      before do
        pipeline.expects(:stderr_messages).returns("stderr messages\n")
      end

      it 'should only output the formatted system error messages' do
        pipeline.error_messages.should match(/
          stderr\smessages\n
          The\sfollowing\ssystem\serrors\swere\sreturned:\n
          #{ sys_err }:\s(.*?)\sfirst\serror\n
          #{ sys_err }:\s(.*?)\ssecond\serror
        /x)
      end
    end
  end # describe '#error_messages'

  describe '#pipeline' do
    context 'when there are multiple system commands to execute' do
      before do
        pipeline.instance_variable_set(:@commands, %w{ one two three })
      end

      it 'should build a pipeline with redirected/collected exit codes' do
        pipeline.send(:pipeline).should ==
          '{ { one 2>&4 ; echo "0|$?:" >&3 ; } | ' +
          '{ two 2>&4 ; echo "1|$?:" >&3 ; } | ' +
          '{ three 2>&4 ; echo "2|$?:" >&3 ; } } 3>&1 1>&2 4>&2'
      end
    end

    context 'when there is only one system command to execute' do
      before do
        pipeline.instance_variable_set(:@commands, ['foo'])
      end

      it 'should build the command line in the same manner, but without pipes' do
        pipeline.send(:pipeline).should ==
          '{ { foo 2>&4 ; echo "0|$?:" >&3 ; } } 3>&1 1>&2 4>&2'
      end
    end
  end # describe '#pipeline'

  describe '#stderr_message' do
    context 'when @stderr has messages' do
      before do
        pipeline.instance_variable_set(:@stderr, "stderr message\n output")
      end

      it 'should return a formatted message with the @stderr messages' do
        pipeline.send(:stderr_messages).should ==
          "  Pipeline STDERR Messages:\n" +
          "  (Note: may be interleaved if multiple commands returned error messages)\n" +
          "\n" +
          "  stderr message\n" +
          "  output\n"
      end
    end

    context 'when @stderr is empty' do
      it 'should return false' do
        pipeline.send(:stderr_messages).should be_false
      end
    end
  end # describe '#stderr_message'

end #describe 'Backup::Pipeline'
