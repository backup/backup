# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Mail do

  describe '#initialize' do

    context 'specifying the delivery_method' do

      it 'creates a new notifier using Mail::SMTP' do
        notifier = Backup::Notifier::Mail.new do |mail|
          mail.delivery_method      = :smtp
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

        notifier.mail.delivery_method.should
            be_an_instance_of ::Mail::SMTP

        notifier.delivery_method.should      == 'smtp'
        notifier.from.should                 == 'my.sender.email@gmail.com'
        notifier.to.should                   == 'my.receiver.email@gmail.com'
        notifier.address.should              == 'smtp.gmail.com'
        notifier.port.should                 == 587
        notifier.domain.should               == 'your.host.name'
        notifier.user_name.should            == 'user'
        notifier.password.should             == 'secret'
        notifier.authentication.should       == 'plain'
        notifier.enable_starttls_auto.should == true
        notifier.openssl_verify_mode.should  be_nil
        notifier.sendmail.should             be_nil
        notifier.sendmail_args.should        be_nil
        notifier.mail_folder.should          be_nil

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end

      it 'creates a new notifier using Mail::Sendmail' do
        notifier = Backup::Notifier::Mail.new do |mail|
          mail.delivery_method      = :sendmail
          mail.from                 = 'my.sender.email@gmail.com'
          mail.to                   = 'my.receiver.email@gmail.com'
          mail.sendmail             = '/path/to/sendmail'
          mail.sendmail_args        = '-i -t -X/tmp/traffic.log'
        end

        notifier.mail.delivery_method.should
            be_an_instance_of ::Mail::Sendmail

        notifier.delivery_method.should      == 'sendmail'
        notifier.from.should                 == 'my.sender.email@gmail.com'
        notifier.to.should                   == 'my.receiver.email@gmail.com'
        notifier.address.should              be_nil
        notifier.port.should                 be_nil
        notifier.domain.should               be_nil
        notifier.user_name.should            be_nil
        notifier.password.should             be_nil
        notifier.authentication.should       be_nil
        notifier.enable_starttls_auto.should be_nil
        notifier.openssl_verify_mode.should  be_nil
        notifier.sendmail.should             == '/path/to/sendmail'
        notifier.sendmail_args.should        == '-i -t -X/tmp/traffic.log'
        notifier.mail_folder.should          be_nil

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end

      it 'creates a new notifier using Mail::FileDelivery' do
        notifier = Backup::Notifier::Mail.new do |mail|
          mail.delivery_method      = :file
          mail.from                 = 'my.sender.email@gmail.com'
          mail.to                   = 'my.receiver.email@gmail.com'
          mail.mail_folder          = '/path/to/backup/mails'
        end

        notifier.mail.delivery_method.should
            be_an_instance_of ::Mail::FileDelivery

        notifier.delivery_method.should      == 'file'
        notifier.from.should                 == 'my.sender.email@gmail.com'
        notifier.to.should                   == 'my.receiver.email@gmail.com'
        notifier.address.should              be_nil
        notifier.port.should                 be_nil
        notifier.domain.should               be_nil
        notifier.user_name.should            be_nil
        notifier.password.should             be_nil
        notifier.authentication.should       be_nil
        notifier.enable_starttls_auto.should be_nil
        notifier.openssl_verify_mode.should  be_nil
        notifier.sendmail.should             be_nil
        notifier.sendmail_args.should        be_nil
        notifier.mail_folder.should          == '/path/to/backup/mails'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end

    end # context 'specifying the delivery_method'

    context 'without specifying the delivery_method' do

      it 'uses Mail::SMTP by default' do
        [nil, :foo, 'foo'].each do |val|
          notifier = Backup::Notifier::Mail.new do |mail|
            mail.delivery_method = val
            mail.from            = 'my.sender.email@gmail.com'
            mail.to              = 'my.receiver.email@gmail.com'
          end

          notifier.delivery_method.should      == 'smtp'
          notifier.from.should                 == 'my.sender.email@gmail.com'
          notifier.to.should                   == 'my.receiver.email@gmail.com'
        end
      end

    end # context 'without specifying the delivery_method'

    describe 'setting configuration defaults' do
      let(:config) { Backup::Configuration::Notifier::Mail }
      after { config.clear_defaults! }

      it 'uses and overrides configuration defaults' do
        config.defaults do |mail|
          mail.delivery_method = :file
          mail.to         = 'some.receiver.email@gmail.com'
          mail.from       = 'default.sender.email@gmail.com'
          mail.on_success = false
        end

        config.delivery_method.should == :file
        config.to.should              == 'some.receiver.email@gmail.com'
        config.from.should            == 'default.sender.email@gmail.com'
        config.on_success.should      == false

        notifier = Backup::Notifier::Mail.new do |mail|
          mail.mail_folder = '/my/backup/mails'
          mail.from = 'my.sender.email@gmail.com'
          mail.on_warning = false
        end

        notifier.delivery_method.should == 'file'
        notifier.mail_folder = '/my/backup/mails'
        notifier.to.should   == 'some.receiver.email@gmail.com'
        notifier.from.should == 'my.sender.email@gmail.com'

        notifier.on_success.should == false
        notifier.on_warning.should == false
        notifier.on_failure.should == true
      end

    end # describe 'setting configuration defaults'

  end # describe '#initialize'

  describe '#perform!' do
    let(:model) { Backup::Model.new('trigger', 'label') {} }
    let(:message) { '[Backup::%s] label (trigger)' }
    let(:notifier) do
      Backup::Notifier::Mail.new do |mail|
        mail.delivery_method = :test
      end
    end

    before do
      notifier.on_success = false
      notifier.on_warning = false
      notifier.on_failure = false
      ::Mail::TestMailer.deliveries.clear
    end

    context 'success' do

      context 'when Notifier#on_success is true' do
        before { notifier.on_success = true }

        it 'sends the notification' do
          notifier.expects(:log!)
          Backup::Template.any_instance.expects(:result).
              with('notifier/mail/success.erb').
              returns('message body')

          notifier.perform!(model)
          sent_message = ::Mail::TestMailer.deliveries.first
          sent_message.subject.should == message % 'Success'
          sent_message.body.should == 'message body'
        end
      end

      context 'when Notifier#on_success is false' do
        it 'does not send the notification' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never

          notifier.perform!(model)
          ::Mail::TestMailer.deliveries.should be_empty
        end
      end

    end # context 'success'

    context 'warning' do
      before { Backup::Logger.stubs(:has_warnings?).returns(true) }

      context 'when Notifier#on_warning is true' do
        before { notifier.on_warning = true }

        it 'sends the notification' do
          notifier.expects(:log!)
          Backup::Template.any_instance.expects(:result).
              with('notifier/mail/warning.erb').
              returns('message body')

          notifier.perform!(model)
          sent_message = ::Mail::TestMailer.deliveries.first
          sent_message.subject.should == message % 'Warning'
          sent_message.body.should == 'message body'
        end
      end

      context 'when Notifier#on_success is true' do
        before { notifier.on_success = true }

        it 'sends the notification' do
          notifier.expects(:log!)
          Backup::Template.any_instance.expects(:result).
              with('notifier/mail/warning.erb').
              returns('message body')

          notifier.perform!(model)
          sent_message = ::Mail::TestMailer.deliveries.first
          sent_message.subject.should == message % 'Warning'
          sent_message.body.should == 'message body'
        end
      end

      context 'when Notifier#on_warning and Notifier#on_success are false' do
        it 'does not send the notification' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never

          notifier.perform!(model)
          ::Mail::TestMailer.deliveries.should be_empty
        end
      end

    end # context 'warning'

    context 'failure' do

      context 'when Notifier#on_failure is true' do
        before { notifier.on_failure = true }

        it 'sends the notification' do
          notifier.expects(:log!)
          Backup::Template.any_instance.expects(:result).
              with('notifier/mail/failure.erb').
              returns('message body')

          notifier.perform!(model, Exception.new)
          sent_message = ::Mail::TestMailer.deliveries.first
          sent_message.subject.should == message % 'Failure'
          sent_message.body.should == 'message body'
        end
      end

      context 'when Notifier#on_failure is false' do
        it 'does not send the notification' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never

          notifier.perform!(model, Exception.new)
          ::Mail::TestMailer.deliveries.should be_empty
        end
      end

    end # context 'failure'

  end # describe '#perform!'
end
