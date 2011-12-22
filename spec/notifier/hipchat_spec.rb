# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Hipchat do
  let(:notifier) do
    Backup::Notifier::Hipchat.new do |notifier|
      notifier.from = 'application'
      notifier.token = 'token'
      notifier.rooms_notified = ['room1', 'room2']
      notifier.notify_users = true
    end
  end

  describe '#initialize' do

    it "sets the correct defaults" do
      notifier.from.should == 'application'
      notifier.token.should == 'token'
      notifier.success_color.should == 'yellow'
      notifier.warning_color.should == 'yellow'
      notifier.failure_color.should == 'yellow'
      notifier.on_success.should == true
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    it 'uses and overrides configuration defaults' do
      Backup::Configuration::Notifier::Hipchat.defaults do |notifier|
        notifier.token = 'old'
        notifier.from = 'before'
        notifier.success_color = 'green'
      end
      hipchat = Backup::Notifier::Hipchat.new do |notifier|
        notifier.token = 'new'
        notifier.from = 'after'
        notifier.failure_color = 'red'
      end

      hipchat.token.should == 'new'
      hipchat.from.should == 'after'
      hipchat.success_color.should == 'green'
      hipchat.warning_color.should == 'yellow'
      hipchat.failure_color.should == 'red'
      hipchat.on_success.should == true
      hipchat.on_warning.should == true
      hipchat.on_failure.should == true
    end

  end # describe '#initialize'

  describe '#perform!' do
    let(:model) { Backup::Model.new('trigger', 'label') {} }
    let(:hipchat_mock) { mock }
    let(:hipchat_client) { HipChat::Client.any_instance }
    let(:message) { '[Backup::%s] label (trigger)' }

    before do
      notifier.on_success = false
      notifier.on_warning = false
      notifier.on_failure = false
      notifier.success_color = 'green'
      notifier.warning_color = 'yellow'
      notifier.failure_color = 'red'
    end

    context 'success' do

      context 'when on_success is true' do
        before { notifier.on_success = true }

        it 'sends success message' do
          notifier.expects(:log!)
          hipchat_client.expects(:[]).with('room1').returns(hipchat_mock)
          hipchat_client.expects(:[]).with('room2').returns(hipchat_mock)
          hipchat_mock.expects(:send).twice.with {|user, msg, hash|
            (user.should == notifier.from) &&
            (msg.should == message % 'Success') &&
            (hash[:color].should == notifier.success_color) &&
            (hash[:notify].should == notifier.notify_users)
          }

          notifier.perform!(model)
        end
      end

      context 'when on_success is false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          hipchat_client.expects(:[]).never

          notifier.perform!(model)
        end
      end

    end # context 'success'

    context 'warning' do
      before { Backup::Logger.stubs(:has_warnings?).returns(true) }

      context 'when on_success is true' do
        before { notifier.on_success = true }

        it 'sends warning message' do
          notifier.expects(:log!)
          hipchat_client.expects(:[]).with('room1').returns(hipchat_mock)
          hipchat_client.expects(:[]).with('room2').returns(hipchat_mock)
          hipchat_mock.expects(:send).twice.with {|user, msg, hash|
            (user.should == notifier.from) &&
            (msg.should == message % 'Warning') &&
            (hash[:color].should == notifier.warning_color) &&
            (hash[:notify].should == notifier.notify_users)
          }

          notifier.perform!(model)
        end
      end

      context 'when on_warning is true' do
        before { notifier.on_warning = true }

        it 'sends warning message' do
          notifier.expects(:log!)
          hipchat_client.expects(:[]).with('room1').returns(hipchat_mock)
          hipchat_client.expects(:[]).with('room2').returns(hipchat_mock)
          hipchat_mock.expects(:send).twice.with {|user, msg, hash|
            (user.should == notifier.from) &&
            (msg.should == message % 'Warning') &&
            (hash[:color].should == notifier.warning_color) &&
            (hash[:notify].should == notifier.notify_users)
          }

          notifier.perform!(model)
        end
      end

      context 'when on_success and on_warning are false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          hipchat_client.expects(:[]).never

          notifier.perform!(model)
        end
      end

    end # context 'warning'

    context 'failure' do

      context 'when on_failure is true' do
        before { notifier.on_failure = true }

        it 'sends failure message' do
          notifier.expects(:log!)
          hipchat_client.expects(:[]).with('room1').returns(hipchat_mock)
          hipchat_client.expects(:[]).with('room2').returns(hipchat_mock)
          hipchat_mock.expects(:send).twice.with {|user, msg, hash|
            (user.should == notifier.from) &&
            (msg.should == message % 'Failure') &&
            (hash[:color].should == notifier.failure_color) &&
            (hash[:notify].should == notifier.notify_users)
          }

          notifier.perform!(model, Exception.new)
        end
      end

      context 'when on_failure is false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          hipchat_client.expects(:[]).never

          notifier.perform!(model, Exception.new)
        end
      end

    end # context 'failure'

    it 'will convert a single room param to an array' do
      notifier.on_success = true
      notifier.rooms_notified = 'one_room'

      hipchat_client.expects(:[]).with('one_room').returns(stub(:send))

      notifier.perform!(model)
      notifier.rooms_notified.should == ['one_room']
    end

  end # describe '#perform!'
end
