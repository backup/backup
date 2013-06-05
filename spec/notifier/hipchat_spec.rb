# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Notifier::Hipchat do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:notifier) { Notifier::Hipchat.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Notifier::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( notifier.token          ).to be_nil
      expect( notifier.from           ).to be_nil
      expect( notifier.rooms_notified ).to eq []
      expect( notifier.notify_users   ).to be(false)
      expect( notifier.success_color  ).to eq 'yellow'
      expect( notifier.warning_color  ).to eq 'yellow'
      expect( notifier.failure_color  ).to eq 'yellow'

      expect( notifier.on_success     ).to be(true)
      expect( notifier.on_warning     ).to be(true)
      expect( notifier.on_failure     ).to be(true)
      expect( notifier.max_retries    ).to be(10)
      expect( notifier.retry_waitsec  ).to be(30)
    end

    it 'configures the notifier' do
      notifier = Notifier::Hipchat.new(model) do |hipchat|
        hipchat.token           = 'my_token'
        hipchat.from            = 'my_from'
        hipchat.rooms_notified  = ['room_a', 'room_b']
        hipchat.notify_users    = true
        hipchat.success_color   = :success_color
        hipchat.warning_color   = :warning_color
        hipchat.failure_color   = :failure_color

        hipchat.on_success    = false
        hipchat.on_warning    = false
        hipchat.on_failure    = false
        hipchat.max_retries   = 5
        hipchat.retry_waitsec = 10
      end

      expect( notifier.token          ).to eq 'my_token'
      expect( notifier.from           ).to eq 'my_from'
      expect( notifier.rooms_notified ).to eq ['room_a', 'room_b']
      expect( notifier.notify_users   ).to be(true)
      expect( notifier.success_color  ).to eq :success_color
      expect( notifier.warning_color  ).to eq :warning_color
      expect( notifier.failure_color  ).to eq :failure_color

      expect( notifier.on_success     ).to be(false)
      expect( notifier.on_warning     ).to be(false)
      expect( notifier.on_failure     ).to be(false)
      expect( notifier.max_retries    ).to be(5)
      expect( notifier.retry_waitsec  ).to be(10)
    end
  end # describe '#initialize'

  describe '#notify!' do
    let(:notifier) {
      Notifier::Hipchat.new(model) do |hipchat|
        hipchat.token           = 'my_token'
        hipchat.from            = 'my_from'
        hipchat.rooms_notified  = ['room_a', 'room_b']
        hipchat.notify_users    = true
        hipchat.success_color   = :success_color
        hipchat.warning_color   = :warning_color
        hipchat.failure_color   = :failure_color
      end
    }
    let(:client) { mock }
    let(:room) { mock }
    let(:message) { '[Backup::%s] test label (test_trigger)' }

    context 'when status is :success' do
      it 'sends a success message' do
        HipChat::Client.expects(:new).in_sequence(s).
            with('my_token').returns(client)
        client.expects(:[]).in_sequence(s).
            with('room_a').returns(room)
        room.expects(:send).in_sequence(s).
            with('my_from', message % 'Success',
                :color => :success_color, :notify => true)
        client.expects(:[]).in_sequence(s).
            with('room_b').returns(room)
        room.expects(:send).in_sequence(s).
            with('my_from', message % 'Success',
                :color => :success_color, :notify => true)

        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'sends a warning message' do
        HipChat::Client.expects(:new).in_sequence(s).
            with('my_token').returns(client)
        client.expects(:[]).in_sequence(s).
            with('room_a').returns(room)
        room.expects(:send).in_sequence(s).
            with('my_from', message % 'Warning',
                :color => :warning_color, :notify => true)
        client.expects(:[]).in_sequence(s).
            with('room_b').returns(room)
        room.expects(:send).in_sequence(s).
            with('my_from', message % 'Warning',
                :color => :warning_color, :notify => true)

        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'sends a failure message' do
        HipChat::Client.expects(:new).in_sequence(s).
            with('my_token').returns(client)
        client.expects(:[]).in_sequence(s).
            with('room_a').returns(room)
        room.expects(:send).in_sequence(s).
            with('my_from', message % 'Failure',
                :color => :failure_color, :notify => true)
        client.expects(:[]).in_sequence(s).
            with('room_b').returns(room)
        room.expects(:send).in_sequence(s).
            with('my_from', message % 'Failure',
                :color => :failure_color, :notify => true)

        notifier.send(:notify!, :failure)
      end
    end

  end # describe '#notify!'

  describe '#rooms_to_notify' do
    it 'returns an array of rooms from a string with a single room name' do
      notifier.rooms_notified = 'my_room'
      expect( notifier.send(:rooms_to_notify) ).to eq ['my_room']
    end

    it 'returns an array of rooms from a comma-delimited string' do
      notifier.rooms_notified = 'room_a, room_b'
      expect( notifier.send(:rooms_to_notify) ).to eq ['room_a', 'room_b']
    end
  end # describe '#rooms_to_notify'

end
end
