# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Campfire do
  let(:notifier) do
    Backup::Notifier::Campfire.new do |campfire|
      campfire.api_token = 'token'
      campfire.subdomain = 'subdomain'
      campfire.room_id   = 'room_id'
    end
  end

  describe '#initialize' do
    it 'sets the correct defaults' do
      notifier.api_token.should == 'token'
      notifier.subdomain.should == 'subdomain'
      notifier.room_id.should   == 'room_id'

      notifier.on_success.should == true
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    it 'uses and overrides configuration defaults' do
      Backup::Configuration::Notifier::Campfire.defaults do |campfire|
        campfire.api_token  = 'old_token'
        campfire.on_success = false
      end
        notifier           = Backup::Notifier::Campfire.new do |campfire|
        campfire.api_token = 'new_token'
      end

      notifier.api_token.should  == 'new_token'
      notifier.on_success.should == false
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end
  end

  describe '#perform!' do
    let(:model)     { Backup::Model.new('trigger', 'label') {} }
    let(:interface) { Backup::Notifier::Campfire::Interface }
    let(:attrs)     { [notifier.room_id, notifier.subdomain, notifier.api_token] }
    let(:room)      { Backup::Notifier::Campfire::Room.new(*attrs) }
    let(:base_uri)  { "https://#{notifier.subdomain}.campfirenow.com" }
    let(:room_url)  { "/room/#{notifier.room_id}/speak.json" }
    let(:message)   { '[Backup::%s] label (trigger)' }

    before do
      notifier.on_success = false
      notifier.on_warning = false
      notifier.on_failure = false
    end

    context 'success' do

      context 'when on_success is true' do
        before { notifier.on_success = true }

        it 'sends success message' do
          notifier.expects(:log!)
          interface.expects(:room).with(*attrs).returns(room)
          interface.expects(:base_uri).with(base_uri)
          interface.expects(:basic_auth).with(notifier.api_token, 'x')
          message_body = message % 'Success'
          interface.expects(:post).with(room_url, :body => {
            :message => { :body => message_body, :type => 'Textmessage' }
          }.to_json)

          notifier.perform!(model)
        end
      end

      context 'when on_success is false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          room.expects(:send_message).never
          interface.expects(:post).never

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
          interface.expects(:room).with(*attrs).returns(room)
          interface.expects(:base_uri).with(base_uri)
          interface.expects(:basic_auth).with(notifier.api_token, 'x')
          message_body = message % 'Warning'
          interface.expects(:post).with(room_url, :body => {
            :message => { :body => message_body, :type => 'Textmessage' }
          }.to_json)

          notifier.perform!(model)
        end
      end

      context 'when on_warning is true' do
        before { notifier.on_warning = true }

        it 'sends warning message' do
          notifier.expects(:log!)
          interface.expects(:room).with(*attrs).returns(room)
          interface.expects(:base_uri).with(base_uri)
          interface.expects(:basic_auth).with(notifier.api_token, 'x')
          message_body = message % 'Warning'
          interface.expects(:post).with(room_url, :body => {
            :message => { :body => message_body, :type => 'Textmessage' }
          }.to_json)

          notifier.perform!(model)
        end
      end

      context 'when on_success and on_warning are false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          room.expects(:send_message).never
          interface.expects(:post).never

          notifier.perform!(model)
        end
      end

    end # context 'warning'

    context 'failure' do

      context 'when on_failure is true' do
        before { notifier.on_failure = true }

        it 'sends failure message' do
          notifier.expects(:log!)
          interface.expects(:room).with(*attrs).returns(room)
          interface.expects(:base_uri).with(base_uri)
          interface.expects(:basic_auth).with(notifier.api_token, 'x')
          message_body = message % 'Failure'
          interface.expects(:post).with(room_url, :body => {
            :message => { :body => message_body, :type => 'Textmessage' }
          }.to_json)

          notifier.perform!(model, Exception.new)
        end
      end

      context 'when on_failure is false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          room.expects(:send_message).never
          interface.expects(:post).never

          notifier.perform!(model, Exception.new)
        end
      end

    end # context 'failure'

  end # describe '#perform!'
end
