# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Notifier::Mail do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:notifier) { Notifier::Mail.new(model) }

  before do
    Notifier::Mail.any_instance.stubs(:utility).
        with(:sendmail).returns('/path/to/sendmail')
    Notifier::Mail.any_instance.stubs(:utility).
        with(:exim).returns('/path/to/exim')
  end

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Notifier::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( notifier.delivery_method      ).to be_nil
      expect( notifier.to                   ).to be_nil
      expect( notifier.from                 ).to be_nil
      expect( notifier.address              ).to be_nil
      expect( notifier.port                 ).to be_nil
      expect( notifier.domain               ).to be_nil
      expect( notifier.user_name            ).to be_nil
      expect( notifier.password             ).to be_nil
      expect( notifier.authentication       ).to be_nil
      expect( notifier.encryption           ).to be_nil
      expect( notifier.openssl_verify_mode  ).to be_nil
      expect( notifier.sendmail_args        ).to be_nil
      expect( notifier.exim_args            ).to be_nil
      expect( notifier.mail_folder          ).to be_nil
      expect( notifier.send_log_on          ).to eq [:warning, :failure]

      expect( notifier.on_success     ).to be(true)
      expect( notifier.on_warning     ).to be(true)
      expect( notifier.on_failure     ).to be(true)
      expect( notifier.max_retries    ).to be(10)
      expect( notifier.retry_waitsec  ).to be(30)
    end

    it 'configures the notifier' do
      notifier = Notifier::Mail.new(model) do |mail|
        mail.delivery_method      = :smtp
        mail.to                   = 'my.receiver.email@gmail.com'
        mail.from                 = 'my.sender.email@gmail.com'
        mail.address              = 'smtp.gmail.com'
        mail.port                 = 587
        mail.domain               = 'your.host.name'
        mail.user_name            = 'user'
        mail.password             = 'secret'
        mail.authentication       = 'plain'
        mail.encryption           = :starttls
        mail.openssl_verify_mode  = :none
        mail.sendmail_args        = '-i -t -X/tmp/traffic.log'
        mail.exim_args            = '-i -t -X/tmp/traffic.log'
        mail.mail_folder          = '/path/to/backup/mails'
        mail.send_log_on          = [:success, :warning, :failure]

        mail.on_success     = false
        mail.on_warning     = false
        mail.on_failure     = false
        mail.max_retries    = 5
        mail.retry_waitsec  = 10
      end

      expect( notifier.delivery_method      ).to eq :smtp
      expect( notifier.to                   ).to eq 'my.receiver.email@gmail.com'
      expect( notifier.from                 ).to eq 'my.sender.email@gmail.com'
      expect( notifier.address              ).to eq 'smtp.gmail.com'
      expect( notifier.port                 ).to eq 587
      expect( notifier.domain               ).to eq 'your.host.name'
      expect( notifier.user_name            ).to eq 'user'
      expect( notifier.password             ).to eq 'secret'
      expect( notifier.authentication       ).to eq 'plain'
      expect( notifier.encryption           ).to eq :starttls
      expect( notifier.openssl_verify_mode  ).to eq :none
      expect( notifier.sendmail_args        ).to eq '-i -t -X/tmp/traffic.log'
      expect( notifier.exim_args            ).to eq '-i -t -X/tmp/traffic.log'
      expect( notifier.mail_folder          ).to eq '/path/to/backup/mails'
      expect( notifier.send_log_on          ).to eq [:success, :warning, :failure]

      expect( notifier.on_success     ).to be(false)
      expect( notifier.on_warning     ).to be(false)
      expect( notifier.on_failure     ).to be(false)
      expect( notifier.max_retries    ).to be(5)
      expect( notifier.retry_waitsec  ).to be(10)
    end
  end # describe '#initialize'

  describe '#notify!' do
    let(:message) { '[Backup::%s] test label (test_trigger)' }

    before do
      notifier.delivery_method = :test
      notifier.to = 'to@email'
      notifier.from = 'from@email'

      ::Mail::TestMailer.deliveries.clear

      Logger.stubs(:messages).returns([
        stub(:formatted_lines => ['line 1', 'line 2']),
        stub(:formatted_lines => ['line 3'])
      ])

      time = Time.now
      model.stubs(:time).returns(time.strftime("%Y.%m.%d.%H.%M.%S"))
      model.stubs(:started_at).returns(time)
      model.stubs(:finished_at).returns(time + 5)
    end

    context 'when status is :success' do
      context 'when send_log_on includes :success' do
        before { notifier.send_log_on = [:success, :warning, :failure] }

        it 'sends a Success email with an attached log' do
          notifier.send(:notify!, :success)

          sent_message = ::Mail::TestMailer.deliveries.first
          filename = "#{ model.time }.#{ model.trigger }.log"

          expect( sent_message.subject          ).to eq message % 'Success'
          expect( sent_message.body.multipart?  ).to be_true
          expect( sent_message.attachments[filename].read ).
              to eq "line 1\nline 2\nline 3"
          expect( sent_message.text_part ).to be_an_instance_of ::Mail::Part
          expect( sent_message.text_part.decoded ).to eq <<-EOS.gsub(/^ +/, '')

            Backup Completed Successfully!

            Job: test label (test_trigger)
            Started:  #{ model.started_at }
            Finished: #{ model.finished_at }
            Duration: 00:00:05

            See the attached backup log for details.

            #{ '=' * 75 }
            Backup v#{ VERSION }
            Ruby: #{ RUBY_DESCRIPTION }

            Project Home:  https://github.com/meskyanichi/backup
            Documentation: https://github.com/meskyanichi/backup/wiki
            Issue Tracker: https://github.com/meskyanichi/backup/issues
          EOS
        end
      end

      context 'when send_log_on does not include :success' do
        it 'sends a Success email with no log attached' do
          notifier.send(:notify!, :success)

          sent_message = ::Mail::TestMailer.deliveries.first
          expect( sent_message.subject          ).to eq message % 'Success'
          expect( sent_message.multipart?       ).to be_false
          expect( sent_message.has_attachments? ).to be_false
          expect( sent_message.body ).to be_an_instance_of ::Mail::Body
          expect( sent_message.body.decoded ).to eq <<-EOS.gsub(/^ +/, '')

            Backup Completed Successfully!

            Job: test label (test_trigger)
            Started:  #{ model.started_at }
            Finished: #{ model.finished_at }
            Duration: 00:00:05

            #{ '=' * 75 }
            Backup v#{ VERSION }
            Ruby: #{ RUBY_DESCRIPTION }

            Project Home:  https://github.com/meskyanichi/backup
            Documentation: https://github.com/meskyanichi/backup/wiki
            Issue Tracker: https://github.com/meskyanichi/backup/issues
          EOS
        end
      end
    end # context 'when status is :success'

    context 'when status is :warning' do
      context 'when send_log_on includes :warning' do
        it 'sends a Warning email with an attached log' do
          notifier.send(:notify!, :warning)

          sent_message = ::Mail::TestMailer.deliveries.first
          filename = "#{ model.time }.#{ model.trigger }.log"

          expect( sent_message.subject          ).to eq message % 'Warning'
          expect( sent_message.body.multipart?  ).to be_true
          expect( sent_message.attachments[filename].read ).
              to eq "line 1\nline 2\nline 3"
          expect( sent_message.text_part ).to be_an_instance_of ::Mail::Part
          expect( sent_message.text_part.decoded ).to eq <<-EOS.gsub(/^ +/, '')

            Backup Completed Successfully (with Warnings)!

            Job: test label (test_trigger)
            Started:  #{ model.started_at }
            Finished: #{ model.finished_at }
            Duration: 00:00:05

            See the attached backup log for details.

            #{ '=' * 75 }
            Backup v#{ VERSION }
            Ruby: #{ RUBY_DESCRIPTION }

            Project Home:  https://github.com/meskyanichi/backup
            Documentation: https://github.com/meskyanichi/backup/wiki
            Issue Tracker: https://github.com/meskyanichi/backup/issues
          EOS
        end
      end

      context 'when send_log_on does not include :warning' do
        before { notifier.send_log_on = [:success, :failure] }

        it 'sends a Warning email with no log attached' do
          notifier.send(:notify!, :warning)

          sent_message = ::Mail::TestMailer.deliveries.first
          expect( sent_message.subject          ).to eq message % 'Warning'
          expect( sent_message.multipart?       ).to be_false
          expect( sent_message.has_attachments? ).to be_false
          expect( sent_message.body ).to be_an_instance_of ::Mail::Body
          expect( sent_message.body.decoded ).to eq <<-EOS.gsub(/^ +/, '')

            Backup Completed Successfully (with Warnings)!

            Job: test label (test_trigger)
            Started:  #{ model.started_at }
            Finished: #{ model.finished_at }
            Duration: 00:00:05

            #{ '=' * 75 }
            Backup v#{ VERSION }
            Ruby: #{ RUBY_DESCRIPTION }

            Project Home:  https://github.com/meskyanichi/backup
            Documentation: https://github.com/meskyanichi/backup/wiki
            Issue Tracker: https://github.com/meskyanichi/backup/issues
          EOS
        end
      end
    end # context 'when status is :warning'

    context 'when status is :failure' do
      context 'when send_log_on includes :failure' do
        it 'sends a Failure email with an attached log' do
          notifier.send(:notify!, :failure)

          sent_message = ::Mail::TestMailer.deliveries.first
          filename = "#{ model.time }.#{ model.trigger }.log"

          expect( sent_message.subject          ).to eq message % 'Failure'
          expect( sent_message.body.multipart?  ).to be_true
          expect( sent_message.attachments[filename].read ).
              to eq "line 1\nline 2\nline 3"
          expect( sent_message.text_part ).to be_an_instance_of ::Mail::Part
          expect( sent_message.text_part.decoded ).to eq <<-EOS.gsub(/^ +/, '')

            Backup Failed!

            Job: test label (test_trigger)
            Started:  #{ model.started_at }
            Finished: #{ model.finished_at }
            Duration: 00:00:05

            See the attached backup log for details.

            #{ '=' * 75 }
            Backup v#{ VERSION }
            Ruby: #{ RUBY_DESCRIPTION }

            Project Home:  https://github.com/meskyanichi/backup
            Documentation: https://github.com/meskyanichi/backup/wiki
            Issue Tracker: https://github.com/meskyanichi/backup/issues
          EOS
        end
      end

      context 'when send_log_on does not include :failure' do
        before { notifier.send_log_on = [:success, :warning] }

        it 'sends a Warning email with no log attached' do
          notifier.send(:notify!, :failure)

          sent_message = ::Mail::TestMailer.deliveries.first
          expect( sent_message.subject          ).to eq message % 'Failure'
          expect( sent_message.multipart?       ).to be_false
          expect( sent_message.has_attachments? ).to be_false
          expect( sent_message.body ).to be_an_instance_of ::Mail::Body
          expect( sent_message.body.decoded ).to eq <<-EOS.gsub(/^ +/, '')

            Backup Failed!

            Job: test label (test_trigger)
            Started:  #{ model.started_at }
            Finished: #{ model.finished_at }
            Duration: 00:00:05

            #{ '=' * 75 }
            Backup v#{ VERSION }
            Ruby: #{ RUBY_DESCRIPTION }

            Project Home:  https://github.com/meskyanichi/backup
            Documentation: https://github.com/meskyanichi/backup/wiki
            Issue Tracker: https://github.com/meskyanichi/backup/issues
          EOS
        end
      end
    end # context 'when status is :failure'

  end # describe '#notify!'

  describe '#new_email' do

    context 'when no delivery_method is set' do
      before { notifier.delivery_method = nil }

      it 'defaults to :smtp' do
        email = notifier.send(:new_email)
        expect( email ).to be_an_instance_of ::Mail::Message
        expect( email.delivery_method ).to be_an_instance_of ::Mail::SMTP
      end
    end

    context 'when delivery_method is :smtp' do
      let(:notifier) {
        Notifier::Mail.new(model) do |mail|
          mail.delivery_method      = :smtp
          mail.to                   = 'my.receiver.email@gmail.com'
          mail.from                 = 'my.sender.email@gmail.com'
          mail.address              = 'smtp.gmail.com'
          mail.port                 = 587
          mail.domain               = 'your.host.name'
          mail.user_name            = 'user'
          mail.password             = 'secret'
          mail.authentication       = 'plain'
          mail.encryption           = :starttls
          mail.openssl_verify_mode  = :none
        end
      }

      it 'should return an email using SMTP' do
        email = notifier.send(:new_email)
        expect( email.delivery_method ).to be_an_instance_of ::Mail::SMTP
      end

      it 'should set the proper options' do
        email = notifier.send(:new_email)
        expect( email.to    ).to eq ['my.receiver.email@gmail.com']
        expect( email.from  ).to eq ['my.sender.email@gmail.com']

        settings = email.delivery_method.settings
        expect( settings[:address]                ).to eq 'smtp.gmail.com'
        expect( settings[:port]                   ).to eq 587
        expect( settings[:domain]                 ).to eq 'your.host.name'
        expect( settings[:user_name]              ).to eq 'user'
        expect( settings[:password]               ).to eq 'secret'
        expect( settings[:authentication]         ).to eq 'plain'
        expect( settings[:enable_starttls_auto]   ).to be(true)
        expect( settings[:openssl_verify_mode]    ).to eq :none
        expect( settings[:ssl]                    ).to be(false)
        expect( settings[:tls]                    ).to be(false)
      end

      it 'should properly set other encryption settings' do
        notifier.encryption = :ssl
        email = notifier.send(:new_email)

        settings = email.delivery_method.settings
        expect( settings[:enable_starttls_auto] ).to be(false)
        expect( settings[:ssl]                  ).to be(true)
        expect( settings[:tls]                  ).to be(false)

        notifier.encryption = :tls
        email = notifier.send(:new_email)

        settings = email.delivery_method.settings
        expect( settings[:enable_starttls_auto] ).to be(false)
        expect( settings[:ssl]                  ).to be(false)
        expect( settings[:tls]                  ).to be(true)
      end
    end

    context 'when delivery_method is :sendmail' do
      let(:notifier) {
        Notifier::Mail.new(model) do |mail|
          mail.delivery_method      = :sendmail
          mail.to                   = 'my.receiver.email@gmail.com'
          mail.from                 = 'my.sender.email@gmail.com'
          mail.sendmail_args        = '-i -t -X/tmp/traffic.log'
        end
      }

      it 'should return an email using Sendmail' do
        email = notifier.send(:new_email)
        expect( email.delivery_method ).to be_an_instance_of ::Mail::Sendmail
      end

      it 'should set the proper options' do
        email = notifier.send(:new_email)

        expect( email.to   ).to eq ['my.receiver.email@gmail.com']
        expect( email.from ).to eq ['my.sender.email@gmail.com']

        settings = email.delivery_method.settings
        expect( settings[:location]   ).to eq '/path/to/sendmail'
        expect( settings[:arguments]  ).to eq '-i -t -X/tmp/traffic.log'
      end
    end

    context 'when delivery_method is :exim' do
      let(:notifier) {
        Notifier::Mail.new(model) do |mail|
          mail.delivery_method      = :exim
          mail.to                   = 'my.receiver.email@gmail.com'
          mail.from                 = 'my.sender.email@gmail.com'
          mail.exim_args            = '-i -t -X/tmp/traffic.log'
        end
      }

      it 'should return an email using Exim' do
        email = notifier.send(:new_email)
        expect( email.delivery_method ).to be_an_instance_of ::Mail::Exim
      end

      it 'should set the proper options' do
        email = notifier.send(:new_email)

        expect( email.to    ).to eq ['my.receiver.email@gmail.com']
        expect( email.from  ).to eq ['my.sender.email@gmail.com']

        settings = email.delivery_method.settings
        expect( settings[:location]  ).to eq '/path/to/exim'
        expect( settings[:arguments] ).to eq '-i -t -X/tmp/traffic.log'
      end
    end

    context 'when delivery_method is :file' do
      let(:notifier) {
        Notifier::Mail.new(model) do |mail|
          mail.delivery_method      = :file
          mail.to                   = 'my.receiver.email@gmail.com'
          mail.from                 = 'my.sender.email@gmail.com'
          mail.mail_folder          = '/path/to/backup/mails'
        end
      }

      it 'should return an email using FileDelievery' do
        email = notifier.send(:new_email)
        expect( email.delivery_method ).to be_an_instance_of ::Mail::FileDelivery
      end

      it 'should set the proper options' do
        email = notifier.send(:new_email)

        expect( email.to    ).to eq ['my.receiver.email@gmail.com']
        expect( email.from  ).to eq ['my.sender.email@gmail.com']

        settings = email.delivery_method.settings
        expect( settings[:location] ).to eq '/path/to/backup/mails'
      end
    end

  end # describe '#new_email'

  describe 'deprecations' do

    describe '#enable_starttls_auto' do
      before do
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(/Use #encryption instead/)
        }
      end

      context 'when set directly' do
        it 'warns and transfers true value' do
          notifier = Notifier::Mail.new(model) do |mail|
            mail.enable_starttls_auto = true
          end
          expect( notifier.encryption ).to eq :starttls
        end

        it 'warns and transfers false value' do
          notifier = Notifier::Mail.new(model) do |mail|
            mail.enable_starttls_auto = false
          end
          expect( notifier.encryption ).to eq :none
        end
      end

      context 'when set as a default' do
        after { Notifier::Mail.clear_defaults! }

        it 'warns and transfers true value' do
          Notifier::Mail.defaults do |mail|
            mail.enable_starttls_auto = true
          end
          notifier = Notifier::Mail.new(model)
          expect( notifier.encryption ).to eq :starttls
        end

        it 'warns and transfers false value' do
          Notifier::Mail.defaults do |mail|
            mail.enable_starttls_auto = false
          end
          notifier = Notifier::Mail.new(model)
          expect( notifier.encryption ).to eq :none
        end
      end
    end # describe '#enable_starttls_auto'

    describe '#sendmail' do
      before do
        # to satisfy Utilities.configure
        File.stubs(:executable?).with('/foo').returns(true)
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use Backup::Utilities\.configure instead/
          )
        }
      end
      after do
        Notifier::Mail.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Notifier::Mail.new(model) do |mail|
            mail.sendmail = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['sendmail'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Notifier::Mail.defaults do |mail|
            mail.sendmail = '/foo'
          end
          Notifier::Mail.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['sendmail'] ).to eq '/foo'
        end
      end
    end # describe '#sendmail'

    describe '#exim' do
      before do
        # to satisfy Utilities.configure
        File.stubs(:executable?).with('/foo').returns(true)
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use Backup::Utilities\.configure instead/
          )
        }
      end
      after do
        Notifier::Mail.clear_defaults!
      end

      context 'when set directly' do
        it 'should issue a deprecation warning and set the replacement value' do
          Notifier::Mail.new(model) do |mail|
            mail.exim = '/foo'
          end
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['exim'] ).to eq '/foo'
        end
      end

      context 'when set as a default' do
        it 'should issue a deprecation warning and set the replacement value' do
          Notifier::Mail.defaults do |mail|
            mail.exim = '/foo'
          end
          Notifier::Mail.new(model)
          # must check directly, since utility() calls are stubbed
          expect( Utilities::UTILITY['exim'] ).to eq '/foo'
        end
      end
    end # describe '#exim'

  end # describe 'deprecations'
end
end
