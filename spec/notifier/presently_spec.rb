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

  describe '#initialize' do
    it 'should sets the correct values' do
      notifier.user_name.should == 'user_name'
      notifier.subdomain.should == 'subdomain'
      notifier.password.should  == 'password'
      notifier.group_id.should  == 'group_id'

      notifier.on_success.should == true
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    context 'when using configuration defaults' do
      after { Backup::Configuration::Notifier::Presently.clear_defaults! }

      it 'should use the configuration defaults' do
        Backup::Configuration::Notifier::Presently.defaults do |presently|
          presently.user_name = 'some_user_name'
          presently.subdomain = 'some_subdomain'
          presently.password  = 'some_password'
          presently.group_id  = 'some_group_id'

          presently.on_success = false
          presently.on_warning = false
          presently.on_failure = false
        end
        notifier = Backup::Notifier::Presently.new(model)
        notifier.user_name.should == 'some_user_name'
        notifier.subdomain.should == 'some_subdomain'
        notifier.password.should  == 'some_password'
        notifier.group_id.should  == 'some_group_id'

        notifier.on_success.should == false
        notifier.on_warning.should == false
        notifier.on_failure.should == false
      end

      it 'should override the configuration defaults' do
        Backup::Configuration::Notifier::Presently.defaults do |presently|
          presently.user_name = 'old_user_name'
          presently.subdomain = 'old_subdomain'
          presently.password  = 'old_password'
          presently.group_id  = 'old_group_id'

          presently.on_success = true
          presently.on_warning = false
          presently.on_failure = false
        end
        notifier = Backup::Notifier::Presently.new(model) do |presently|
          presently.user_name = 'new_user_name'
          presently.subdomain = 'new_subdomain'
          presently.password  = 'new_password'
          presently.group_id  = 'new_group_id'

          presently.on_success = false
          presently.on_warning = true
          presently.on_failure = true
        end

        notifier.user_name.should == 'new_user_name'
        notifier.subdomain.should == 'new_subdomain'
        notifier.password.should  == 'new_password'
        notifier.group_id.should  == 'new_group_id'

        notifier.on_success.should == false
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when using configuration defaults'
  end

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
