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

  it 'should be a subclass of Notifier::Base' do
    Backup::Notifier::Hipchat.
      superclass.should == Backup::Notifier::Base
  end

  describe '#initialize' do
    after { Backup::Notifier::Hipchat.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Notifier::Hipchat.any_instance.expects(:load_defaults!)
      notifier
    end

    it 'should pass the model reference to Base' do
      notifier.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
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

      it 'should use default values if none are given' do
        notifier = Backup::Notifier::Hipchat.new(model)
        notifier.token.should           be_nil
        notifier.from.should            be_nil
        notifier.rooms_notified.should  == []
        notifier.notify_users.should    == false
        notifier.success_color.should   == 'yellow'
        notifier.warning_color.should   == 'yellow'
        notifier.failure_color.should   == 'yellow'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Notifier::Hipchat.defaults do |n|
          n.token          = 'old'
          n.from           = 'before'
          n.success_color  = 'green'
          n.on_failure     = false
        end
      end

      it 'should use pre-configured defaults' do
        notifier = Backup::Notifier::Hipchat.new(model)

        notifier.token.should           == 'old'
        notifier.from.should            == 'before'
        notifier.rooms_notified.should  == []
        notifier.notify_users.should    == false
        notifier.success_color.should   == 'green'
        notifier.warning_color.should   == 'yellow'
        notifier.failure_color.should   == 'yellow'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == false
      end

      it 'should override pre-configured defaults' do
        notifier = Backup::Notifier::Hipchat.new(model) do |n|
          n.token          = 'new'
          n.from           = 'after'
          n.failure_color  = 'red'
          n.on_success     = false
          n.on_failure     = true
        end

        notifier.token.should          == 'new'
        notifier.from.should           == 'after'
        notifier.success_color.should  == 'green'
        notifier.warning_color.should  == 'yellow'
        notifier.failure_color.should  == 'red'

        notifier.on_success.should     == false
        notifier.on_warning.should     == true
        notifier.on_failure.should     == true
      end
    end # context 'when pre-configured defaults have been set'
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

    it 'should handle rooms_notified being set as a comma-delimited string' do
      notifier.rooms_notified = 'a_room, another room'
      HipChat::Client.expects(:new).with('token').returns(client)
      client.expects(:[]).with('a_room').returns(room)
      client.expects(:[]).with('another room').returns(room)
      room.expects(:send).with(
        'application',
        'a message',
        {:color => 'a color', :notify => false}
      ).twice

      notifier.send(:send_message, 'a message', 'a color')
    end

    context 'when notify_users is set to true' do
      before { notifier.notify_users = true }

      it 'should notify rooms with :notify => true' do
        HipChat::Client.expects(:new).with('token').returns(client)
        client.expects(:[]).with('room1').returns(room)
        client.expects(:[]).with('room2').returns(room)
        room.expects(:send).with(
          'application',
          'a message',
          {:color => 'a color', :notify => true}
        ).twice

        notifier.send(:send_message, 'a message', 'a color')
      end
    end

    context 'when notify_users is set to false' do
      before { notifier.notify_users = false }

      it 'should notify rooms with :notify => false' do
        HipChat::Client.expects(:new).with('token').returns(client)
        client.expects(:[]).with('room1').returns(room)
        client.expects(:[]).with('room2').returns(room)
        room.expects(:send).with(
          'application',
          'a message',
          {:color => 'a color', :notify => false}
        ).twice

        notifier.send(:send_message, 'a message', 'a color')
      end
    end
  end
end
