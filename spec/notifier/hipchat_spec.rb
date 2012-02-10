# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Hipchat do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) do
    Backup::Notifier::Hipchat.new(model) do |notifier|
      notifier.token = 'token'
      notifier.from = 'application'
      notifier.rooms_notified = ['room1', 'room2']
    end
  end

  describe '#initialize' do

    it 'should set the correct values and defaults' do
      notifier.token.should           == 'token'
      notifier.from.should            == 'application'
      notifier.rooms_notified.should  == ['room1', 'room2']
      notifier.notify_users.should    == false
      notifier.success_color.should   == 'yellow'
      notifier.warning_color.should   == 'yellow'
      notifier.failure_color.should   == 'yellow'

      notifier.on_success.should == true
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Notifier::Hipchat.clear_defaults! }

      it 'should use the configuration defaults' do
        Backup::Configuration::Notifier::Hipchat.defaults do |notifier|
          notifier.token          = 'old'
          notifier.from           = 'before'
          notifier.success_color  = 'green'

          notifier.on_failure     = false
        end
        hipchat = Backup::Notifier::Hipchat.new(model)

        hipchat.token.should           == 'old'
        hipchat.from.should            == 'before'
        hipchat.rooms_notified.should  == []
        hipchat.notify_users.should    == false
        hipchat.success_color.should   == 'green'
        hipchat.warning_color.should   == 'yellow'
        hipchat.failure_color.should   == 'yellow'

        hipchat.on_success.should == true
        hipchat.on_warning.should == true
        hipchat.on_failure.should == false
      end

      it 'should override the configuration defaults' do
        Backup::Configuration::Notifier::Hipchat.defaults do |notifier|
          notifier.token          = 'old'
          notifier.from           = 'before'
          notifier.success_color  = 'green'

          notifier.on_failure     = false
        end
        hipchat = Backup::Notifier::Hipchat.new(model) do |notifier|
          notifier.token          = 'new'
          notifier.from           = 'after'
          notifier.failure_color  = 'red'

          notifier.on_success     = false
          notifier.on_failure     = true
        end

        hipchat.token.should          == 'new'
        hipchat.from.should           == 'after'
        hipchat.success_color.should  == 'green'
        hipchat.warning_color.should  == 'yellow'
        hipchat.failure_color.should  == 'red'

        hipchat.on_success.should     == false
        hipchat.on_warning.should     == true
        hipchat.on_failure.should     == true
      end
    end # context 'when setting configuration defaults'

  end # describe '#initialize'

  describe '#notify!' do
    before do
      notifier.success_color = 'green'
      notifier.warning_color = 'yellow'
      notifier.failure_color = 'red'
    end

    context 'when status is :success' do
      it 'should send Success message' do
        notifier.expects(:send_message).with(
          '[Backup::Success] test label (test_trigger)', 'green'
        )
        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'should send Warning message' do
        notifier.expects(:send_message).with(
          '[Backup::Warning] test label (test_trigger)', 'yellow'
        )
        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'should send Failure message' do
        notifier.expects(:send_message).with(
          '[Backup::Failure] test label (test_trigger)', 'red'
        )
        notifier.send(:notify!, :failure)
      end
    end
  end # describe '#notify!'

  describe '#send_message' do
    let(:client)  { mock }
    let(:room)    { mock }

    it 'should handle rooms_notified being set as a single room string' do
      notifier.rooms_notified = 'a_room'
      HipChat::Client.expects(:new).with('token').returns(client)
      client.expects(:[]).with('a_room').returns(room)
      room.expects(:send).with(
        'application',
        'a message',
        {:color => 'a color', :notify => false}
      )

      notifier.send(:send_message, 'a message', 'a color')
    end

    context 'when notify_users is set to true' do
      before { notifier.notify_users = true }

      it 'should notify rooms with :notify => true' do
        HipChat::Client.expects(:new).with('token').returns(client)

        client.expects(:[]).with('room1').returns(room)
        room.expects(:send).with(
          'application',
          'a message',
          {:color => 'a color', :notify => true}
        )

        client.expects(:[]).with('room2').returns(room)
        room.expects(:send).with(
          'application',
          'a message',
          {:color => 'a color', :notify => true}
        )

        notifier.send(:send_message, 'a message', 'a color')
      end
    end

    context 'when notify_users is set to false' do
      before { notifier.notify_users = false }

      it 'should notify rooms with :notify => false' do
        HipChat::Client.expects(:new).with('token').returns(client)

        client.expects(:[]).with('room1').returns(room)
        room.expects(:send).with(
          'application',
          'a message',
          {:color => 'a color', :notify => false}
        )

        client.expects(:[]).with('room2').returns(room)
        room.expects(:send).with(
          'application',
          'a message',
          {:color => 'a color', :notify => false}
        )

        notifier.send(:send_message, 'a message', 'a color')
      end
    end
  end
end
