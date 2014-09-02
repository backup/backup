# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
  describe Notifier::Ses do
    let(:model) { Model.new(:test_trigger, 'test label') }
    let(:notifier) { Notifier::Ses.new(model) }

    it_behaves_like 'a class that includes Config::Helpers'
    it_behaves_like 'a subclass of Notifier::Base'

    describe '#initialize' do
      it 'provides default values' do
        expect(notifier.to).to be_nil
        expect(notifier.from).to be_nil
        expect(notifier.send_log_on).to eq [:warning, :failure]

        expect(notifier.on_success).to be(true)
        expect(notifier.on_warning).to be(true)
        expect(notifier.on_failure).to be(true)
        expect(notifier.max_retries).to be(10)
        expect(notifier.retry_waitsec).to be(30)
      end

      it 'configures the notifier' do
        notifier = Notifier::Ses.new(model) do |mail|
          mail.to = 'my.receiver.email@gmail.com'
          mail.from = 'my.sender.email@gmail.com'
          mail.send_log_on = [:success, :warning, :failure]

          mail.on_success = false
          mail.on_warning = false
          mail.on_failure = false
          mail.max_retries = 5
          mail.retry_waitsec = 10
        end

        expect(notifier.to).to eq 'my.receiver.email@gmail.com'
        expect(notifier.from).to eq 'my.sender.email@gmail.com'
        expect(notifier.send_log_on).to eq [:success, :warning, :failure]

        expect(notifier.on_success).to be(false)
        expect(notifier.on_warning).to be(false)
        expect(notifier.on_failure).to be(false)
        expect(notifier.max_retries).to be(5)
        expect(notifier.retry_waitsec).to be(10)
      end
    end

    describe '#notify!' do
      let(:fake_ses) { Object.new }
      let(:notifier) {
        f = fake_ses
        Notifier::Ses.new(model) { |ses|
          ses.access_key_id = 'my_access_key_id'
          ses.secret_access_key = 'my_secret_access_key'
          ses.stubs(:client).returns(f)
        }
      }

      context 'when status is :success' do
        it 'sends a success message' do
          fake_ses.expects(:send_raw_email).once.with{ |mail|
            expect(mail.subject).to eq('[Backup::Success] test label (test_trigger)')
            expect(mail.body.raw_source).to match_regex('Backup Completed Successfully!')
          }

          notifier.send(:notify!, :success)
        end
      end

      context 'when status is :warning' do
        it 'sends a warning message' do
          fake_ses.expects(:send_raw_email).once.with{ |mail|
            expect(mail.subject).to eq('[Backup::Warning] test label (test_trigger)')
            expect(mail.parts[0].body.raw_source).to match_regex('with Warnings')
            expect(mail.attachments[0].filename).to match_regex('log')
          }

          notifier.send(:notify!, :warning)
        end
      end

      context 'when status is :failure' do
        it 'sends a failure message' do
          fake_ses.expects(:send_raw_email).once.with{ |mail|
            expect(mail.subject).to eq('[Backup::Failure] test label (test_trigger)')
            expect(mail.parts[0].body.raw_source).to match_regex('Backup Failed!')
            expect(mail.attachments[0].filename).to match_regex('log')
          }

          notifier.send(:notify!, :failure)
        end
      end
    end
  end
end
