# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Notifier::Mail do
  before do
    Backup::Configuration::Notifier::Mail.defaults do |mail|
      mail.delivery_method      = :file
      mail.from                 = 'my.sender.email@gmail.com'
      mail.to                   = 'my.receiver.email@gmail.com'
      mail.address              = 'smtp.gmail.com'
      mail.port                 = 587
      mail.domain               = 'your.host.name'
      mail.user_name            = 'user'
      mail.password             = 'secret'
      mail.authentication       = 'plain'
      mail.enable_starttls_auto = true
      mail.openssl_verify_mode  = 'none'
      mail.sendmail             = '/path/to/sendmail'
      mail.sendmail_args        = '-i -t -X/tmp/traffic.log'
      mail.mail_folder          = '/path/to/backup/mails'
    end
  end
  after { Backup::Configuration::Notifier::Mail.clear_defaults! }

  it 'should set the default Mail configuration' do
    mail = Backup::Configuration::Notifier::Mail
    mail.delivery_method.should       == :file
    mail.from.should                  == 'my.sender.email@gmail.com'
    mail.to.should                    == 'my.receiver.email@gmail.com'
    mail.address.should               == 'smtp.gmail.com'
    mail.port.should                  == 587
    mail.domain.should                == 'your.host.name'
    mail.user_name.should             == 'user'
    mail.password.should              == 'secret'
    mail.authentication.should        == 'plain'
    mail.enable_starttls_auto.should  == true
    mail.openssl_verify_mode.should   == 'none'
    mail.sendmail.should              == '/path/to/sendmail'
    mail.sendmail_args.should         == '-i -t -X/tmp/traffic.log'
    mail.mail_folder.should           == '/path/to/backup/mails'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Notifier::Mail.clear_defaults!

      mail = Backup::Configuration::Notifier::Mail
      mail.delivery_method.should       == nil
      mail.from.should                  == nil
      mail.to.should                    == nil
      mail.address.should               == nil
      mail.port.should                  == nil
      mail.domain.should                == nil
      mail.user_name.should             == nil
      mail.password.should              == nil
      mail.authentication.should        == nil
      mail.enable_starttls_auto.should  == nil
      mail.openssl_verify_mode.should   == nil
      mail.sendmail.should              == nil
      mail.sendmail_args.should         == nil
      mail.mail_folder.should           == nil
    end
  end
end
