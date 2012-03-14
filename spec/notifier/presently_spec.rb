# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Presently do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) do
    Backup::Notifier::Presently.new(model) do |presently|
      presently.user_name = 'user_name'
      presently.subdomain = 'subdomain'
      presently.password  = 'password'
      presently.group_id  = 'group_id'
    end
  end

  it 'should be a subclass of Notifier::Base' do
    Backup::Notifier::Presently.
      superclass.should == Backup::Notifier::Base
  end

  describe '#initialize' do
    after { Backup::Notifier::Presently.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Notifier::Presently.any_instance.expects(:load_defaults!)
      notifier
    end

    it 'should pass the model reference to Base' do
      notifier.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        notifier.user_name.should == 'user_name'
        notifier.subdomain.should == 'subdomain'
        notifier.password.should  == 'password'
        notifier.group_id.should  == 'group_id'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end

      it 'should use default values if none are given' do
        notifier = Backup::Notifier::Presently.new(model)
        notifier.user_name.should be_nil
        notifier.subdomain.should be_nil
        notifier.password.should  be_nil
        notifier.group_id.should  be_nil

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Notifier::Presently.defaults do |n|
          n.user_name = 'some_user_name'
          n.subdomain = 'some_subdomain'
          n.password  = 'some_password'
          n.group_id  = 'some_group_id'

          n.on_success = false
          n.on_warning = false
          n.on_failure = false
        end
      end

      it 'should use pre-configured defaults' do
        notifier = Backup::Notifier::Presently.new(model)
        notifier.user_name.should == 'some_user_name'
        notifier.subdomain.should == 'some_subdomain'
        notifier.password.should  == 'some_password'
        notifier.group_id.should  == 'some_group_id'

        notifier.on_success.should == false
        notifier.on_warning.should == false
        notifier.on_failure.should == false
      end

      it 'should override pre-configured defaults' do
        notifier = Backup::Notifier::Presently.new(model) do |n|
          n.user_name = 'new_user_name'
          n.subdomain = 'new_subdomain'
          n.password  = 'new_password'
          n.group_id  = 'new_group_id'

          n.on_success = false
          n.on_warning = true
          n.on_failure = true
        end

        notifier.user_name.should == 'new_user_name'
        notifier.subdomain.should == 'new_subdomain'
        notifier.password.should  == 'new_password'
        notifier.group_id.should  == 'new_group_id'

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
      client = mock
      Backup::Notifier::Presently::Client.expects(:new).
          with('subdomain', 'user_name', 'password', 'group_id').
          returns(client)
      client.expects(:update).with('a message')

      notifier.send(:send_message, 'a message')
    end
  end
end

describe Backup::Notifier::Presently::Client do
  let(:client) do
    Backup::Notifier::Presently::Client.new(
      'subdomain', 'user_name', 'password', 'group_id'
    )
  end

  it 'should include HTTParty' do
    Backup::Notifier::Presently::Client.
        included_modules.should include(HTTParty)
  end

  it 'should setup the proper values' do
    client.subdomain.should == 'subdomain'
    client.user_name.should == 'user_name'
    client.password.should  == 'password'
    client.group_id.should  == 'group_id'

    Backup::Notifier::Presently::Client.base_uri.
        should == 'https://subdomain.presently.com'
    Backup::Notifier::Presently::Client.default_options[:basic_auth].
        should == {:username => 'user_name', :password => 'password' }
  end

  describe '#update' do
    context 'when a group_id is specified' do
      it 'should post the given message with the specified group' do
        Backup::Notifier::Presently::Client.expects(:post).with(
          '/api/twitter/statuses/update.json',
          :body => {
            :status => 'd @group_id a message',
            :source => 'Backup Notifier'
          }
        )
        client.update('a message')
      end
    end

    context 'when no group_id is specified' do
      before { client.group_id = nil }
      it 'should just post the given message' do
        Backup::Notifier::Presently::Client.expects(:post).with(
          '/api/twitter/statuses/update.json',
          :body => {
            :status => 'a message',
            :source => 'Backup Notifier'
          }
        )
        client.update('a message')
      end
    end
  end
end
