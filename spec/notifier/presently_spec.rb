# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Presently do
  let(:notifier) do
    Backup::Notifier::Presently.new do |presently|
      presently.user_name = 'user_name'
      presently.subdomain = 'subdomain'
      presently.password   = 'password'
      presently.group_id   = 'group_id'
    end
  end

  it do
    notifier.user_name.should == 'user_name'
    notifier.subdomain.should == 'subdomain'
    notifier.password.should   == 'password'
    notifier.group_id.should   == 'group_id'

    notifier.on_success.should == true
    notifier.on_failure.should == true
  end

  describe 'defaults' do
    it do
      Backup::Configuration::Notifier::Presently.defaults do |presently|
        presently.user_name  = 'old_user_name'
        presently.on_success = false
        presently.on_failure = true
      end
      notifier           = Backup::Notifier::Presently.new do |presently|
        presently.user_name = 'new_user_name'
      end

      notifier.user_name.should  == 'new_user_name'
      notifier.on_success.should == false
      notifier.on_failure.should == true
    end
  end

  describe '#initialize' do
    it do
      Backup::Notifier::Presently.any_instance.expects(:set_defaults!)
      Backup::Notifier::Presently.new
    end
  end

  describe '#perform!' do
    let(:model) { Backup::Model.new('blah', 'blah') {} }
    before do
      notifier.on_success = false
      notifier.on_failure = false
    end

    context "when successful" do
      it do
        Backup::Logger.expects(:message).with("Backup::Notifier::Presently started notifying about the process.")
        notifier.expects("notify_success!")
        notifier.on_success = true
        notifier.perform!(model)
      end

      it do
        notifier.expects("notify_success!").never
        notifier.on_success = false
        notifier.perform!(model)
      end
    end

    context "when failed" do
      it do
        Backup::Logger.expects(:message).with("Backup::Notifier::Presently started notifying about the process.")
        notifier.expects("notify_failure!")
        notifier.on_failure = true
        notifier.perform!(model, Exception.new)
      end

      it do
        notifier.expects("notify_failure!").never
        notifier.on_failure = false
        notifier.perform!(model, Exception.new)
      end
    end
  end

  describe Backup::Notifier::Presently::Client do
    let(:client) do
      Backup::Notifier::Presently::Client.new('subdomain', 'user_name', 'password', 'group_id')
    end

    it do
      client.user_name.should == 'user_name'
      client.subdomain.should == 'subdomain'
      client.password.should   == 'password'
      client.group_id.should == 'group_id'
    end
  end
end
