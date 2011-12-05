# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Mail do

  describe '#initialize' do

    it 'creates a new notifier' do
      notifier = Backup::Notifier::Mail.new do |mail|
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
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    it 'uses and overrides configuration defaults' do
      Backup::Configuration::Notifier::Mail.defaults do |mail|
        mail.to         = 'some.receiver.email@gmail.com'
        mail.from       = 'default.sender.email@gmail.com'
        mail.on_success = false
      end

      notifier = Backup::Notifier::Mail.new do |mail|
        mail.from = 'my.sender.email@gmail.com'
        mail.on_warning = false
      end

      notifier.to.should   == 'some.receiver.email@gmail.com'
      notifier.from.should == 'my.sender.email@gmail.com'
      notifier.on_success.should == false
      notifier.on_warning.should == false
      notifier.on_failure.should == true
    end

  end # describe '#initialize'

  describe '#perform!' do
    let(:model) { Backup::Model.new('trigger', 'label') {} }
    let(:message) { '[Backup::%s] label (trigger)' }
    let(:notifier) do
      notifier = Backup::Notifier::Mail.new
      ::Mail.defaults { delivery_method :test }
      notifier.mail = ::Mail.new
      notifier
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
