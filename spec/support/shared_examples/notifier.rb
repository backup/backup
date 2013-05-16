# encoding: utf-8

module Backup
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
          Logger.expects(:info).with(
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
          Logger.expects(:info).never
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
          Logger.expects(:info).with(
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
          Logger.expects(:info).with(
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
          Logger.expects(:info).never
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
          Logger.expects(:info).with(
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
          Logger.expects(:info).never
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
          Logger.expects(:info).with(
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
          Logger.expects(:info).never
          notifier.expects(:notify!).never
          notifier.perform!
        end
      end
    end

    specify 'notifiers only log exceptions' do
      model.stubs(:exit_status).returns(0)
      notifier.expects(:notify!).with(:success).raises(Exception.new 'error message')

      Logger.expects(:error).with do |err|
        expect( err ).to be_an_instance_of Errors::NotifierError
        expect( err.message ).to match(/#{ notifier_name } Failed!/)
        expect( err.message ).to match(/error message/)
      end

      notifier.perform!
    end
  end # describe '#perform'

end
end
