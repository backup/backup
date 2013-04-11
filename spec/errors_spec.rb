# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

# Note: none of these tests require the use of the ErrorsHelper
describe 'Errors::Error' do
  let(:klass) { Backup::Errors::Error }

  it 'allow errors to cascade through the system' do
    class ErrorA < klass; end
    class ErrorB < klass; end
    class ErrorC < klass; end
    class ErrorD < klass; end

    expect do
      begin
        begin
          begin
            raise ErrorA, 'an error occurred in Zone A'
          rescue => err
            raise ErrorB.wrap(err, <<-EOS)
              an error occurred in Zone B

              the following error should give a reason
            EOS
          end
        rescue => err
          raise ErrorC.wrap(err)
        end
      rescue => err
        raise ErrorD.wrap(err, 'an error occurred in Zone D')
      end
    end.to raise_error(ErrorD,
      "ErrorD: an error occurred in Zone D\n" +
      "  Reason: ErrorC\n" +
      "  ErrorB: an error occurred in Zone B\n" +
      "  \n" +
      "  the following error should give a reason\n" +
      "  Reason: ErrorA\n" +
      "  an error occurred in Zone A"
    )
  end

  describe '#initialize' do

    it 'creates a StandardError' do
      klass.new.should be_a_kind_of StandardError
    end

    context 'when given a message' do

      it 'formats a simple message' do
        err = klass.new('error message')
        err.message.should == 'Error: error message'
      end

      it 'formats a multi-line message' do
        err = klass.new("   error message\n" +
          "     This is a multi-line error message.\n" +
          "It should be properly indented.   ")

        err.message.should == "Error: error message\n" +
            "  This is a multi-line error message.\n" +
            "  It should be properly indented."
      end

      context 'when given an original error' do

        it 'includes the original error' do
          orig_err = StandardError.new('original message')
          err = klass.new('error message', orig_err)
          err.message.should == "Error: error message\n" +
              "  Reason: StandardError\n" +
              "  original message"
        end

        it 'formats all messages' do
          orig_err = StandardError.new(" original message\n" +
            "     This is a multi-line error message.\n" +
            "It should be properly indented.")
          err = klass.new("   error message\n" +
            "     This is a multi-line error message.\n" +
            "It should be properly indented.   ", orig_err)

          err.message.should == "Error: error message\n" +
              "  This is a multi-line error message.\n" +
              "  It should be properly indented.\n" +
              "  Reason: StandardError\n" +
              "  original message\n" +
              "  This is a multi-line error message.\n" +
              "  It should be properly indented."
        end

        it 'uses the original error backtrace' do
          begin
            raise StandardError.new
          rescue => err
            klass.new(nil, err).backtrace.
                should == err.backtrace
          end
        end

        it 'reports if original error had no message' do
          orig_err = StandardError.new
          err = klass.new('error message', orig_err)
          err.message.should == "Error: error message\n" +
              "  Reason: StandardError (no message given)"
        end

      end # context 'when given an original error'

      context 'when given an original Errors::Error' do
        let(:subklass) do
          class SubKlass < klass; end
          SubKlass
        end

        it 'includes the original error' do
          orig_err = subklass.new('original message')
          err = klass.new('error message', orig_err)
          err.message.should == "Error: error message\n" +
              "  Reason: SubKlass\n" +
              "  original message"
        end

        it 'formats all messages' do
          orig_err = subklass.new(" original message\n" +
            "     This is a multi-line error message.\n" +
            "It should be properly indented.")
          err = klass.new("   error message\n" +
            "     This is a multi-line error message.\n" +
            "It should be properly indented.   ", orig_err)

          err.message.should == "Error: error message\n" +
              "  This is a multi-line error message.\n" +
              "  It should be properly indented.\n" +
              "  Reason: SubKlass\n" +
              "  original message\n" +
              "  This is a multi-line error message.\n" +
              "  It should be properly indented."
        end

        it 'uses the original error backtrace' do
          begin
            raise subklass.new
          rescue => err
            klass.new(nil, err).backtrace.
                should == err.backtrace
          end
        end

        it 'reports if original error had no message' do
          orig_err = subklass.new
          err = klass.new('error message', orig_err)
          err.message.should == "Error: error message\n" +
              "  Reason: SubKlass (no message given)"
        end

      end # context 'when given an original Errors::Error'

    end # context 'when given a message'

    context 'when given no message' do

      it 'strips the module namespace from the default message' do
        err = klass.new
        err.message.should == 'Error'
      end

      context 'when given an original error' do

        it 'uses the original error message' do
          orig_err = StandardError.new
          err = klass.new(nil, orig_err)
          err.message.should == 'Error: StandardError'

          orig_err = StandardError.new('original message')
          err = klass.new(nil, orig_err)
          err.message.should == 'Error: StandardError: original message'

          orig_err = StandardError.new(" original message\n" +
            "     This is a multi-line error message.\n" +
            "It should be properly indented.")
          err = klass.new(nil, orig_err)
          err.message.should == "Error: StandardError: original message\n" +
              "  This is a multi-line error message.\n" +
              "  It should be properly indented."
        end

      end # context 'when given an original error'

      context 'when given an original Errors::Error' do
        let(:subklass) do
          class SubKlass < klass; end
          SubKlass
        end

        it 'uses the original error message' do
          orig_err = subklass.new
          err = klass.new(nil, orig_err)
          err.message.should == 'Error: SubKlass'

          orig_err = subklass.new('original message')
          err = klass.new(nil, orig_err)
          err.message.should == 'Error: SubKlass: original message'

          orig_err = subklass.new(" original message\n" +
            "     This is a multi-line error message.\n" +
            "It should be properly indented.")
          err = klass.new(nil, orig_err)
          err.message.should == "Error: SubKlass: original message\n" +
              "  This is a multi-line error message.\n" +
              "  It should be properly indented."
        end

      end # context 'when given an original Errors::Error'

    end # context 'when given no message'

  end # describe '#initialize'

  describe '#wrap' do
    describe 'swaps the parameters to provide a cleaner way to' do

      it 'raise a wrapped error with a message' do
        orig_err = StandardError.new <<-EOS
          original message
          This is a multi-line error message.
          It should be properly indented.
        EOS

        expect do
          raise klass.wrap(orig_err), <<-EOS
            error message
            This is a multi-line error message.
            It should be properly indented.
          EOS
        end.to raise_error(klass,
          "Error: error message\n" +
          "  This is a multi-line error message.\n" +
          "  It should be properly indented.\n" +
          "  Reason: StandardError\n" +
          "  original message\n" +
          "  This is a multi-line error message.\n" +
          "  It should be properly indented."
        )
      end

      it 'return a wrapped error with a message' do
        orig_err = StandardError.new <<-EOS
          original message
          This is a multi-line error message.
          It should be properly indented.
        EOS

        err = klass.wrap(orig_err, <<-EOS)
          error message
          This will wrap the original error
          and it's message will be given below
        EOS

        err.message.should ==
          "Error: error message\n" +
          "  This will wrap the original error\n" +
          "  and it's message will be given below\n" +
          "  Reason: StandardError\n" +
          "  original message\n" +
          "  This is a multi-line error message.\n" +
          "  It should be properly indented."
      end

    end # describe 'swaps the parameters to provide a cleaner way to'
  end # describe '#wrap'

end # describe 'Errors::Error'

describe 'ErrorHelper' do
  let(:base) { Backup::Errors }

  it 'dynamically creates namespaces and subclasses of Errors::Error' do
    Backup::Errors::FooBarError.new.
        should be_a_kind_of base::Error
    Backup::Errors::Foo::Bar::Error.new.
        should be_a_kind_of base::Error
  end

  context 'new error classes created within new namespaces' do
    it 'retain the added portion of namespace in their messages' do
      orig_err = StandardError.new('original message')
      err = base::FooMod::FooError.new('error message', orig_err)
      err.message.should ==
          "FooMod::FooError: error message\n" +
          "  Reason: StandardError\n" +
          "  original message"

      err2 = base::Foo::Bar::Mod::FooBarError.wrap(err, 'foobar message')
      err2.message.should ==
          "Foo::Bar::Mod::FooBarError: foobar message\n" +
          "  Reason: FooMod::FooError\n" +
          "  error message\n" +
          "  Reason: StandardError\n" +
          "  original message"
    end
  end

end # describe ErrorHelper
