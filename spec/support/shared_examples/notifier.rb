# encoding: utf-8

shared_examples 'a subclass of Notifier::Base' do
  let(:notifier) { described_class.new(model) }
  let(:notifier_name) { described_class.name.sub('Backup::', '') }

  describe '#perform' do

    context 'when the model succeeded without warnings' do
      before { model.stubs(:exit_status).returns(0) }

      context 'when notify_on_success is true' do
        before do
          notifier.on_success = true
          notifier.on_warning = false
          notifier.on_failure = false
        end

        it 'sends a notification' do
          Backup::Logger.expects(:info).with(
            "Sending notification using #{ notifier_name }..."
          )
          notifier.expects(:notify!).with(:success)
          notifier.perform!
        end
      end

      context 'when notify_on_success is false' do
        before do
          notifier.on_success = false
          notifier.on_warning = true
          notifier.on_failure = true
        end

        it 'does nothing' do
          Backup::Logger.expects(:info).never
          notifier.expects(:notify!).never
          notifier.perform!
        end
      end
    end

    context 'when the model succeeded with warnings' do
      before { model.stubs(:exit_status).returns(1) }

      context 'when notify_on_success is true' do
        before do
          notifier.on_success = true
          notifier.on_warning = false
          notifier.on_failure = false
        end

        it 'sends a notification' do
          Backup::Logger.expects(:info).with(
            "Sending notification using #{ notifier_name }..."
          )
          notifier.expects(:notify!).with(:warning)
          notifier.perform!
        end
      end

      context 'when notify_on_warning is true' do
        before do
          notifier.on_success = false
          notifier.on_warning = true
          notifier.on_failure = false
        end

        it 'sends a notification' do
          Backup::Logger.expects(:info).with(
            "Sending notification using #{ notifier_name }..."
          )
          notifier.expects(:notify!).with(:warning)
          notifier.perform!
        end
      end

      context 'when notify_on_success and notify_on_warning are false' do
        before do
          notifier.on_success = false
          notifier.on_warning = false
          notifier.on_failure = true
        end

        it 'does nothing' do
          Backup::Logger.expects(:info).never
          notifier.expects(:notify!).never
          notifier.perform!
        end
      end
    end

    context 'when the model failed (non-fatal)' do
      before { model.stubs(:exit_status).returns(2) }

      context 'when notify_on_failure is true' do
        before do
          notifier.on_success = false
          notifier.on_warning = false
          notifier.on_failure = true
        end

        it 'sends a notification' do
          Backup::Logger.expects(:info).with(
            "Sending notification using #{ notifier_name }..."
          )
          notifier.expects(:notify!).with(:failure)
          notifier.perform!
        end
      end

      context 'when notify_on_failure is false' do
        before do
          notifier.on_success = true
          notifier.on_warning = true
          notifier.on_failure = false
        end

        it 'does nothing' do
          Backup::Logger.expects(:info).never
          notifier.expects(:notify!).never
          notifier.perform!
        end
      end
    end

    context 'when the model failed (fatal)' do
      before { model.stubs(:exit_status).returns(3) }

      context 'when notify_on_failure is true' do
        before do
          notifier.on_success = false
          notifier.on_warning = false
          notifier.on_failure = true
        end

        it 'sends a notification' do
          Backup::Logger.expects(:info).with(
            "Sending notification using #{ notifier_name }..."
          )
          notifier.expects(:notify!).with(:failure)
          notifier.perform!
        end
      end

      context 'when notify_on_failure is false' do
        before do
          notifier.on_success = true
          notifier.on_warning = true
          notifier.on_failure = false
        end

        it 'does nothing' do
          Backup::Logger.expects(:info).never
          notifier.expects(:notify!).never
          notifier.perform!
        end
      end
    end

    specify 'only logs exceptions' do
      model.stubs(:exit_status).returns(0)
      notifier.expects(:notify!).with(:success).
          raises(Exception.new 'error message')

      Backup::Logger.expects(:error).with do |err|
        expect( err ).to be_an_instance_of Backup::Notifier::Error
        expect( err.message ).to match(/#{ notifier_name } Failed!/)
        expect( err.message ).to match(/error message/)
      end

      notifier.perform!
    end

    specify 'retries failed attempts' do
      model.stubs(:exit_status).returns(0)
      notifier.max_retries = 2

      logger_calls = 0
      Backup::Logger.expects(:info).times(3).with do |arg|
        logger_calls += 1
        case logger_calls
        when 1
          expect( arg ).to eq "Sending notification using #{ notifier_name }..."
        when 2
          expect( arg ).to be_an_instance_of Backup::Notifier::Error
          expect( arg.message ).to match('RuntimeError: standard error')
          expect( arg.message ).to match('Retry #1 of 2.')
        when 3
          expect( arg ).to be_an_instance_of Backup::Notifier::Error
          expect( arg.message ).to match('Timeout::Error')
          expect( arg.message ).to match('Retry #2 of 2.')
        end
      end

      notifier.expects(:sleep).with(30).twice

      s = sequence ''
      notifier.expects(:notify!).in_sequence(s).raises('standard error')
      notifier.expects(:notify!).in_sequence(s).raises(Timeout::Error.new)
      notifier.expects(:notify!).in_sequence(s).raises('final error')

      Backup::Logger.expects(:error).in_sequence(s).with do |err|
        expect( err ).to be_an_instance_of Backup::Notifier::Error
        expect( err.message ).to match(/#{ notifier_name } Failed!/)
        expect( err.message ).to match(/final error/)
      end

      notifier.perform!
    end

  end # describe '#perform'

end
