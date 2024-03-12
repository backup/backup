shared_examples "a subclass of Notifier::Base" do
  let(:notifier) { described_class.new(model) }
  let(:notifier_name) { described_class.name.sub("Backup::", "") }

  describe "#perform" do
    context "when the model succeeded without warnings" do
      before { allow(model).to receive(:exit_status).and_return(0) }

      context "when notify_on_success is true" do
        before do
          notifier.on_success = true
          notifier.on_warning = false
          notifier.on_failure = false
        end

        it "sends a notification" do
          expect(Backup::Logger).to receive(:info).with(
            "Sending notification using #{notifier_name}..."
          )
          expect(notifier).to receive(:notify!).with(:success)
          notifier.perform!
        end
      end

      context "when notify_on_success is false" do
        before do
          notifier.on_success = false
          notifier.on_warning = true
          notifier.on_failure = true
        end

        it "does nothing" do
          expect(Backup::Logger).to receive(:info).never
          expect(notifier).to receive(:notify!).never
          notifier.perform!
        end
      end
    end

    context "when the model succeeded with warnings" do
      before { allow(model).to receive(:exit_status).and_return(1) }

      context "when notify_on_success is true" do
        before do
          notifier.on_success = true
          notifier.on_warning = false
          notifier.on_failure = false
        end

        it "sends a notification" do
          expect(Backup::Logger).to receive(:info).with(
            "Sending notification using #{notifier_name}..."
          )
          expect(notifier).to receive(:notify!).with(:warning)
          notifier.perform!
        end
      end

      context "when notify_on_warning is true" do
        before do
          notifier.on_success = false
          notifier.on_warning = true
          notifier.on_failure = false
        end

        it "sends a notification" do
          expect(Backup::Logger).to receive(:info).with(
            "Sending notification using #{notifier_name}..."
          )
          expect(notifier).to receive(:notify!).with(:warning)
          notifier.perform!
        end
      end

      context "when notify_on_success and notify_on_warning are false" do
        before do
          notifier.on_success = false
          notifier.on_warning = false
          notifier.on_failure = true
        end

        it "does nothing" do
          expect(Backup::Logger).to receive(:info).never
          expect(notifier).to receive(:notify!).never
          notifier.perform!
        end
      end
    end

    context "when the model failed (non-fatal)" do
      before { allow(model).to receive(:exit_status).and_return(2) }

      context "when notify_on_failure is true" do
        before do
          notifier.on_success = false
          notifier.on_warning = false
          notifier.on_failure = true
        end

        it "sends a notification" do
          expect(Backup::Logger).to receive(:info).with(
            "Sending notification using #{notifier_name}..."
          )
          expect(notifier).to receive(:notify!).with(:failure)
          notifier.perform!
        end
      end

      context "when notify_on_failure is false" do
        before do
          notifier.on_success = true
          notifier.on_warning = true
          notifier.on_failure = false
        end

        it "does nothing" do
          expect(Backup::Logger).to receive(:info).never
          expect(notifier).to receive(:notify!).never
          notifier.perform!
        end
      end
    end

    context "when the model failed (fatal)" do
      before { allow(model).to receive(:exit_status).and_return(3) }

      context "when notify_on_failure is true" do
        before do
          notifier.on_success = false
          notifier.on_warning = false
          notifier.on_failure = true
        end

        it "sends a notification" do
          expect(Backup::Logger).to receive(:info).with(
            "Sending notification using #{notifier_name}..."
          )
          expect(notifier).to receive(:notify!).with(:failure)
          notifier.perform!
        end
      end

      context "when notify_on_failure is false" do
        before do
          notifier.on_success = true
          notifier.on_warning = true
          notifier.on_failure = false
        end

        it "does nothing" do
          expect(Backup::Logger).to receive(:info).never
          expect(notifier).to receive(:notify!).never
          notifier.perform!
        end
      end
    end

    specify "only logs exceptions" do
      allow(model).to receive(:exit_status).and_return(0)
      expect(notifier).to receive(:notify!).with(:success)
        .and_raise(Exception.new("error message"))

      expect(Backup::Logger).to receive(:error) do |err|
        expect(err).to be_an_instance_of Backup::Notifier::Error
        expect(err.message).to match(/#{ notifier_name } Failed!/)
        expect(err.message).to match(/error message/)
      end

      notifier.perform!
    end

    specify "retries failed attempts" do
      allow(model).to receive(:exit_status).and_return(0)
      notifier.max_retries = 2

      logger_calls = 0
      expect(Backup::Logger).to receive(:info).exactly(3).times do |arg|
        logger_calls += 1
        case logger_calls
        when 1
          expect(arg).to eq "Sending notification using #{notifier_name}..."
        when 2
          expect(arg).to be_an_instance_of Backup::Notifier::Error
          expect(arg.message).to match("RuntimeError: standard error")
          expect(arg.message).to match("Retry #1 of 2.")
        when 3
          expect(arg).to be_an_instance_of Backup::Notifier::Error
          expect(arg.message).to match("Timeout::Error")
          expect(arg.message).to match("Retry #2 of 2.")
        end
      end

      expect(notifier).to receive(:sleep).with(30).twice

      expect(notifier).to receive(:notify!).ordered.and_raise("standard error")
      expect(notifier).to receive(:notify!).ordered.and_raise(Timeout::Error.new)
      expect(notifier).to receive(:notify!).ordered.and_raise("final error")

      expect(Backup::Logger).to receive(:error).ordered do |err|
        expect(err).to be_an_instance_of Backup::Notifier::Error
        expect(err.message).to match(/#{ notifier_name } Failed!/)
        expect(err.message).to match(/final error/)
      end

      notifier.perform!
    end
  end # describe '#perform'
end
