# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Campfire do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) do
    Backup::Notifier::Campfire.new(model) do |campfire|
      campfire.api_token = 'token'
      campfire.subdomain = 'subdomain'
      campfire.room_id   = 'room_id'
    end
  end

  it 'should be a subclass of Notifier::Base' do
    Backup::Notifier::Campfire.
      superclass.should == Backup::Notifier::Base
  end

  describe '#initialize' do
    after { Backup::Notifier::Campfire.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Notifier::Campfire.any_instance.expects(:load_defaults!)
      notifier
    end

    it 'should pass the model reference to Base' do
      notifier.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        notifier.api_token.should == 'token'
        notifier.subdomain.should == 'subdomain'
        notifier.room_id.should   == 'room_id'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end

      it 'should use default values if none are given' do
        notifier = Backup::Notifier::Campfire.new(model)
        notifier.api_token.should be_nil
        notifier.subdomain.should be_nil
        notifier.room_id.should   be_nil

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Notifier::Campfire.defaults do |n|
          n.api_token  = 'some_token'
          n.subdomain  = 'some_subdomain'
          n.room_id    = 'some_room_id'

          n.on_success = false
          n.on_warning = false
          n.on_failure = false
        end
      end

      it 'should use pre-configured defaults' do
        notifier = Backup::Notifier::Campfire.new(model)
        notifier.api_token.should == 'some_token'
        notifier.subdomain.should == 'some_subdomain'
        notifier.room_id.should   == 'some_room_id'

        notifier.on_success.should == false
        notifier.on_warning.should == false
        notifier.on_failure.should == false
      end

      it 'should override pre-configured defaults' do
        notifier = Backup::Notifier::Campfire.new(model) do |n|
          n.api_token  = 'new_token'
          n.subdomain  = 'new_subdomain'
          n.room_id    = 'new_room_id'

          n.on_success = false
          n.on_warning = true
          n.on_failure = true
        end

        notifier.api_token.should == 'new_token'
        notifier.subdomain.should == 'new_subdomain'
        notifier.room_id.should   == 'new_room_id'

        notifier.on_success.should == false
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#notify!' do
    context 'when status is :success' do
      it 'should send Success message' do
        notifier.expects(:send_message).with(
          '[Backup::Success] test label (test_trigger)'
        )
        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'should send Warning message' do
        notifier.expects(:send_message).with(
          '[Backup::Warning] test label (test_trigger)'
        )
        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'should send Failure message' do
        notifier.expects(:send_message).with(
          '[Backup::Failure] test label (test_trigger)'
        )
        notifier.send(:notify!, :failure)
      end
    end
  end # describe '#notify!'

  describe '#send_message' do
    it 'should send a message' do
      room = mock
      Backup::Notifier::Campfire::Interface.expects(:room).
          with('room_id', 'subdomain', 'token').returns(room)
      room.expects(:message).with('a message')

      notifier.send(:send_message, 'a message')
    end
  end

end

describe 'Backup::Notifier::Campfire::Interface' do
  let(:interface) { Backup::Notifier::Campfire::Interface }

  it 'should include HTTParty' do
    interface.included_modules.should include(HTTParty)
  end

  it 'should set the proper headers' do
    interface.headers['Content-Type'].should == 'application/json'
  end

  describe '.room' do
    let(:room) { mock }

    it 'should create and return a new Room' do
      Backup::Notifier::Campfire::Room.expects(:new).
          with('room_id', 'subdomain', 'api_token').returns(room)

      interface.room('room_id', 'subdomain', 'api_token').should == room
    end
  end
end

describe 'Backup::Notifier::Campfire::Room' do
  let(:room) do
    Backup::Notifier::Campfire::Room.new('room_id', 'subdomain', 'api_token')
  end

  it 'should set the given values for the room' do
    room.room_id.should   == 'room_id'
    room.subdomain.should == 'subdomain'
    room.api_token.should == 'api_token'
  end

  describe '#message' do
    it 'should wrap #send_message' do
      room.expects(:send_message).with('a message')

      room.message('a message')
    end
  end

  describe '#send_message' do
    it 'should pass a JSON formatted HTTParty.post to #post' do
      room.expects(:post).with(
        'speak', {
          :body => MultiJson.encode(
            { :message => { :body => 'a message', :type => 'Textmessage' } }
          )
        }
      )
      room.send(:send_message, 'a message')
    end
  end

  describe '#post' do
    let(:interface) { Backup::Notifier::Campfire::Interface }

    it 'should send an HTTParty.post with the given options through Interface' do
      room.expects(:room_url_for).with('an_action').returns('a_room_url')
      interface.expects(:base_uri).with('https://subdomain.campfirenow.com')
      interface.expects(:basic_auth).with('api_token', 'x')
      interface.expects(:post).with('a_room_url', { :hash => 'of options' })

      room.send(:post, 'an_action', :hash => 'of options')
    end
  end

  describe '#room_url_for' do
    it 'should return a properly formated url for the given action' do
      room.send(:room_url_for, 'my_action').should ==
         '/room/room_id/my_action.json'
    end
  end
end
