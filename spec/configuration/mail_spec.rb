# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Configuration::Mail do
  before do
    Backup::Configuration::Mail.defaults do |mail|
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

  it 'should set the default Mail configuration' do
    mail = Backup::Configuration::Mail
    mail.from.should                 == 'my.sender.email@gmail.com'
    mail.to.should                   == 'my.receiver.email@gmail.com'
    mail.address.should              == 'smtp.gmail.com'
    mail.port.should                 == 587
    mail.domain.should               == 'your.host.name'
    mail.user_name.should            == 'user'
    mail.password.should             == 'secret'
    mail.authentication.should       == 'plain'
    mail.enable_starttls_auto.should == true
  end
end
