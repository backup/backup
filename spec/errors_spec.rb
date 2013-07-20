# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

module Backup
describe 'Backup Errors' do

shared_examples 'a nested exception' do
  let(:class_name) { described_class.name.sub(/^Backup::/, '') }

  context 'with stubbed constants' do
    before do
      ErrorA = Class.new(described_class)
      ErrorB = Class.new(described_class)
      ErrorC = Class.new(described_class)
    end
    after do
      Backup.send(:remove_const, :ErrorA)
      Backup.send(:remove_const, :ErrorB)
      Backup.send(:remove_const, :ErrorC)
    end

    it 'allows errors to cascade through the system' do
      expect do
        begin
          begin
            begin
              raise StandardError, 'error message'
            rescue => err
              raise ErrorA.wrap(err), <<-EOS
                an error occurred in Zone A

                the following error should give a reason
              EOS
            end
          rescue Exception => err
            raise ErrorB.wrap(err)
          end
        rescue Exception => err
          raise ErrorC.wrap(err), 'an error occurred in Zone C'
        end
      end.to raise_error {|err|
        expect( err.message ).to eq(
          "ErrorC: an error occurred in Zone C\n" +
          "--- Wrapped Exception ---\n" +
          "ErrorB\n" +
          "--- Wrapped Exception ---\n" +
          "ErrorA: an error occurred in Zone A\n" +
          "  \n" +
          "  the following error should give a reason\n" +
          "--- Wrapped Exception ---\n" +
          "StandardError: error message"
        )
      }
    end
  end

  context 'with no wrapped exception' do

    describe '#initialize' do

      it 'sets message to class name when not given' do
        err = described_class.new
        expect( err.message ).to eq class_name
      end

      it 'prefixes given message with class name' do
        err = described_class.new('a message')
        expect( err.message ).to eq class_name + ': a message'
      end

      it 'formats message' do
        err = described_class.new(<<-EOS)
          error message
          this is a multi-line message

          the above blank line will remain
          the blank line below will not

        EOS
        expect( err.message ).to eq(
          "#{ class_name }: error message\n" +
          "  this is a multi-line message\n" +
          "  \n" +
          "  the above blank line will remain\n" +
          "  the blank line below will not"
        )
      end

      # This usage wouldn't be expected if using this Error class,
      # since you would typically use .wrap, but this is the default
      # behavior for Ruby if you want to raise an exception that takes
      # it's message from another exception.
      #
      #     begin
      #       ...code...
      #     rescue => other_error
      #       raise MyError, other_error
      #     end
      #
      # Under 1.8.7/1.9.2, the message is the result of other_err.inspect,
      # but under 1.9.3 you get other_err.message.
      # This Error class uses other_error.message under all versions.
      # Note that this will format the message.
      it 'accepts message from another error' do
        other_err = StandardError.new " error\nmessage "
        err = described_class.new(other_err)
        expect( err.message ).to eq class_name + ": error\n  message"
      end

    end # describe '#initialize'

    # i.e. use of raise with Error class
    describe '.exception' do

      it 'sets message to class name when not given' do
        expect do
          raise described_class
        end.to raise_error {|err|
          expect( err.message ).to eq class_name
        }
      end

      it 'prefixes given message with class name' do
        expect do
          raise described_class, 'a message'
        end.to raise_error {|err|
          expect( err.message ).to eq class_name + ': a message'
        }
      end

      it 'formats message' do
        expect do
          raise described_class, <<-EOS
            error message
            this is a multi-line message

            the above blank line will remain
            the blank line below will not

          EOS
        end.to raise_error {|err|
          expect( err.message ).to eq(
            "#{ class_name }: error message\n" +
            "  this is a multi-line message\n" +
            "  \n" +
            "  the above blank line will remain\n" +
            "  the blank line below will not"
          )
        }
      end

      # see note under '#initialize'
      it 'accepts message from another error' do
        expect do
          begin
            raise StandardError, " wrapped error\nmessage "
          rescue => err
            raise described_class, err
          end
        end.to raise_error {|err|
          expect( err.message ).to eq(
            "#{ class_name }: wrapped error\n" +
            "  message"
          )
        }
      end

      it 'allows backtrace to be set (with message)' do
        expect do
          raise described_class, 'error message', ['bt']
        end.to raise_error {|err|
          expect( err.message   ).to eq class_name + ': error message'
          expect( err.backtrace ).to eq ['bt']
        }
      end

      it 'allows backtrace to be set (without message)' do
        expect do
          raise described_class, nil, ['bt']
        end.to raise_error {|err|
          expect( err.message   ).to eq class_name
          expect( err.backtrace ).to eq ['bt']
        }
      end
    end # describe '.exception'

    # i.e. use of raise with an instance of Error
    describe '#exception' do

      it 'sets message to class name when not given' do
        expect do
          err = described_class.new
          raise err
        end.to raise_error {|err|
          expect( err.message ).to eq class_name
        }
      end

      it 'prefixes given message with class name' do
        expect do
          err = described_class.new 'a message'
          raise err
        end.to raise_error {|err|
          expect( err.message ).to eq class_name + ': a message'
        }
      end

      it 'formats message' do
        expect do
          err = described_class.new(<<-EOS)
            error message
            this is a multi-line message

            the above blank line will remain
            the blank line below will not

          EOS
          raise err
        end.to raise_error {|err|
          expect( err.message ).to eq(
            "#{ class_name }: error message\n" +
            "  this is a multi-line message\n" +
            "  \n" +
            "  the above blank line will remain\n" +
            "  the blank line below will not"
          )
        }
      end

      it 'allows message to be overridden' do
        expect do
          err = described_class.new 'error message'
          raise err, 'new message'
        end.to raise_error {|err|
          expect( err.message ).to eq class_name + ': new message'
        }
      end

      # see note under '#initialize'
      it 'accepts message from another error' do
        expect do
          begin
            raise StandardError, " wrapped error\nmessage "
          rescue => err
            err2 = described_class.new 'message to be replaced'
            raise err2, err
          end
        end.to raise_error {|err|
          expect( err.message ).to eq(
            "#{ class_name }: wrapped error\n" +
            "  message"
          )
        }
      end

      it 'allows backtrace to be set (with new message)' do
        initial_error = nil
        expect do
          err = described_class.new 'error message'
          initial_error = err
          raise err, 'new message', ['bt']
        end.to raise_error {|err|
          expect( err.message   ).to eq class_name + ': new message'
          expect( err.backtrace ).to eq ['bt']
          # when a message is given, a new error is returned
          expect( err ).not_to be initial_error
        }
      end

      it 'allows backtrace to be set (without new message)' do
        initial_error = nil
        expect do
          err = described_class.new 'error message'
          initial_error = err
          raise err, nil, ['bt']
        end.to raise_error {|err|
          expect( err.backtrace ).to eq ['bt']
          expect( err.message   ).to eq class_name + ': error message'
          # when no message is given, returns self
          expect( err ).to be initial_error
        }
      end

      it 'retains backtrace (with message given)' do
        initial_error = nil
        expect do
          begin
            raise described_class, 'foo', ['bt']
          rescue Exception => err
            initial_error = err
            raise err, 'bar'
          end
        end.to raise_error {|err|
          expect( err.backtrace ).to eq ['bt']
          expect( err.message   ).to eq class_name + ': bar'
          # when a message is given, a new error is returned
          expect( err ).not_to be initial_error
        }
      end

      it 'retains backtrace (without message given)' do
        initial_error = nil
        expect do
          begin
            raise described_class, 'foo', ['bt']
          rescue Exception => err
            initial_error = err
            raise err
          end
        end.to raise_error {|err|
          expect( err.backtrace ).to eq ['bt']
          # when no message is given, returns self
          expect( err ).to be initial_error
        }
      end
    end # describe '#exception'

  end # context 'with no wrapped exception'

  context 'with a wrapped exception' do

    describe '.wrap' do

      it 'wraps #initialize to reverse parameters' do
        ex = mock
        described_class.expects(:new).with(nil, ex)
        described_class.expects(:new).with('error message', ex)

        described_class.wrap(ex)
        described_class.wrap(ex, 'error message')
      end

      it 'appends wrapped error message' do
        orig_err = StandardError.new 'wrapped error message'
        err = described_class.wrap(orig_err, 'error message')
        expect( err.message ).to eq(
          "#{ class_name }: error message\n" +
          "--- Wrapped Exception ---\n" +
          "StandardError: wrapped error message"
        )
      end

      it 'leaves wrapped error message formatting as-is' do
        orig_err = StandardError.new " wrapped error\nmessage "
        err = described_class.wrap(orig_err, <<-EOS)
          error message

          this error is wrapping another error
        EOS
        expect( err.message ).to eq(
          "#{ class_name }: error message\n" +
          "  \n" +
          "  this error is wrapping another error\n" +
          "--- Wrapped Exception ---\n" +
          "StandardError:  wrapped error\n" +
          "message "
        )
      end

    end # describe '.wrap'

    # i.e. use of raise with an instance of Error
    describe '#exception' do

      it 'appends wrapped error message' do
        expect do
          begin
            raise StandardError, " wrapped error\nmessage "
          rescue => err
            raise described_class.wrap(err), <<-EOS
              error message

              this error is wrapping another error
            EOS
          end
        end.to raise_error {|err|
          expect( err.message ).to eq(
            "#{ class_name }: error message\n" +
            "  \n" +
            "  this error is wrapping another error\n" +
            "--- Wrapped Exception ---\n" +
            "StandardError:  wrapped error\n" +
            "message "
          )
        }
      end

      # see note under '#initialize'
      it 'accepts message from another error' do
        expect do
          begin
            raise StandardError, " wrapped error\nmessage "
          rescue => err
            raise described_class.wrap(err), err
          end
        end.to raise_error {|err|
          expect( err.message ).to eq(
            "#{ class_name }: wrapped error\n" +
            "  message\n" +
            "--- Wrapped Exception ---\n" +
            "StandardError:  wrapped error\n" +
            "message "
          )
        }
      end

      it 'uses backtrace from wrapped exception' do
        expect do
          begin
            raise StandardError, 'wrapped error message', ['bt']
          rescue => err
            raise described_class.wrap(err), 'error message'
          end
        end.to raise_error {|err|
          expect( err.message ).to eq(
            "#{ class_name }: error message\n" +
            "--- Wrapped Exception ---\n" +
            "StandardError: wrapped error message"
          )
          expect( err.backtrace ).to eq ['bt']
        }
      end

      it 'allows wrapped error backtrace to be overridden' do
        expect do
          begin
            raise StandardError, 'wrapped error message', ['bt']
          rescue => err
            raise described_class.wrap(err), 'error message', ['new bt']
          end
        end.to raise_error {|err|
          expect( err.message ).to eq(
            "#{ class_name }: error message\n" +
            "--- Wrapped Exception ---\n" +
            "StandardError: wrapped error message"
          )
          expect( err.backtrace ).to eq ['new bt']
        }
      end

      # Since a new message is given, a new error will be created
      # which would take the bt from the wrapped exception (nil).
      # So, the existing bt is set on the new error in this case.
      # With no message given (a simple re-raise), #exception would simply
      # return self, in which case the bt set by raise would remain.
      # It would be rare for a wrapped exception not to have a bt.
      it 'retains backtrace if wrapped error has none' do
        expect do
          begin
            err = StandardError.new 'foo'
            raise described_class.wrap(err), nil, ['bt']
          rescue Exception => err2
            raise err2, 'bar'
          end
        end.to raise_error {|err|
          expect( err.backtrace ).to eq ['bt']
        }
      end

    end # describe '#exception'

  end # context 'with a wrapped exception'

end # shared_examples 'a nested exception'

describe Error do
  it_behaves_like 'a nested exception'
end

describe FatalError do
  it_behaves_like 'a nested exception'
end

end # describe 'Backup Errors'
end
