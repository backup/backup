# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Notifier::Prowl do
  let(:notifier) do
    Backup::Notifier::Prowl.new do |prowl|
      prowl.application = 'application'
      prowl.api_key     = 'api_key'
    end
  end

  it do
    notifier.application = 'application'
    notifier.api_key     = 'api_key'

    notifier.on_success.should == true
    notifier.on_failure.should == true
  end

  describe 'defaults' do
    it do
      Backup::Configuration::Notifier::Prowl.defaults do |prowl|
        prowl.application  = 'my_default_application'
        prowl.on_success   = false
        prowl.on_failure   = true
      end
      notifier = Backup::Notifier::Prowl.new do |prowl|
        prowl.api_key = 'my_own_api_key'
      end

      notifier.application.should == 'my_default_application'
      notifier.api_key.should     == 'my_own_api_key'
      notifier.on_success.should  == false
      notifier.on_failure.should  == true
    end
  end

  describe '#initialize' do
    it do
      Backup::Notifier::Prowl.any_instance.expects(:set_defaults!)
      Backup::Notifier::Prowl.new
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
        Backup::Logger.expects(:message).with("Backup::Notifier::Prowl started notifying about the process.")
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
        Backup::Logger.expects(:message).with("Backup::Notifier::Prowl started notifying about the process.")
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
end
