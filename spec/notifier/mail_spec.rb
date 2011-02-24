# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Notifier::Mail do
  let(:notifier) do
    Backup::Notifier::Mail.new do |mail|
      mail.from                 = 'my.sender.email@gmail.com'
      mail.to                   = 'my.receiver.email@gmail.com'
      mail.address              = 'smtp.gmail.com'
      mail.port                 = 587
      mail.domain               = 'your.host.name'
      mail.user_name            = 'user'
      mail.password             = 'secret'
      mail.authentication       = 'plain'
      mail.enable_starttls_auto = true
    end
  end

  it do
    notifier.from.should                 == 'my.sender.email@gmail.com'
    notifier.to.should                   == 'my.receiver.email@gmail.com'
    notifier.address.should              == 'smtp.gmail.com'
    notifier.port.should                 == 587
    notifier.domain.should               == 'your.host.name'
    notifier.user_name.should            == 'user'
    notifier.password.should             == 'secret'
    notifier.authentication.should       == 'plain'
    notifier.enable_starttls_auto.should == true

    notifier.on_success.should == true
    notifier.on_failure.should == true
  end

  describe 'defaults' do
    it do
      Backup::Configuration::Notifier::Mail.defaults do |mail|
        mail.to         = 'some.receiver.email@gmail.com'
        mail.on_success = false
        mail.on_failure = true
      end
      notifier = Backup::Notifier::Mail.new do |mail|
        mail.from = 'my.sender.email@gmail.com'
      end

      notifier.to.should   == 'some.receiver.email@gmail.com'
      notifier.from.should == 'my.sender.email@gmail.com'
      notifier.on_success.should == false
      notifier.on_failure.should == true
    end
  end

  describe '#initialize' do
    it do
      Backup::Notifier::Mail.any_instance.expects(:set_defaults!)
      Backup::Notifier::Mail.new
    end
  end

  describe '#perform!' do
    context "when successful" do
      it do
        notifier.expects("notify_success!")
        notifier.on_success = true
        notifier.perform!(nil)
      end

      it do
        notifier.expects("notify_success!").never
        notifier.on_success = false
        notifier.perform!(nil)
      end
    end

    context "when failed" do
      it do
        notifier.expects("notify_failure!")
        notifier.on_failure = true
        notifier.perform!(nil, Exception.new)
      end

      it do
        notifier.expects("notify_failure!").never
        notifier.on_failure = false
        notifier.perform!(nil, Exception.new)
      end
    end
  end
end
