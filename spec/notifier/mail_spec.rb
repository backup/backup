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
      Backup::Notifier::Configuration::Mail.defaults do |mail|
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
end
