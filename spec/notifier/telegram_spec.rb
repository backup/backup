# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Notifier::Telegram do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:notifier) { Notifier::Telegram.new(model) }

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Notifier::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( notifier.bot_token  ).to be_nil
      expect( notifier.chat_id    ).to be_nil

      expect( notifier.on_success     ).to be(true)
      expect( notifier.on_warning     ).to be(true)
      expect( notifier.on_failure     ).to be(true)
      expect( notifier.max_retries    ).to be(10)
      expect( notifier.retry_waitsec  ).to be(30)
    end

    it 'configures the notifier' do
      notifier = Notifier::Telegram.new(model) do |telegram|
        telegram.bot_token = 'bot_api_token'
        telegram.chat_id   = '@chatpublicname'

        telegram.on_success    = false
        telegram.on_warning    = false
        telegram.on_failure    = false
        telegram.max_retries   = 5
        telegram.retry_waitsec = 10
      end

      expect( notifier.bot_token  ).to eq 'bot_api_token'
      expect( notifier.chat_id    ).to eq '@chatpublicname'

      expect( notifier.on_success     ).to be(false)
      expect( notifier.on_warning     ).to be(false)
      expect( notifier.on_failure     ).to be(false)
      expect( notifier.max_retries    ).to be(5)
      expect( notifier.retry_waitsec  ).to be(10)
    end
  end # describe '#initialize'

  describe '#notify!' do
    let(:notifier) {
      Notifier::Telegram.new(model) do |telegram|
        telegram.bot_token = 'bot_api_token'
        telegram.chat_id   = '@chatpublicname'
      end
    }
    let(:form_data) {
      'chat_id=chatpublicname&' +
      'message=%5BBackup%3A%3A' + 'STATUS' + '%5D+test+label+%28test_trigger%29'
    }

    context 'when status is :success' do
      it 'sends a success message' do
        Excon.expects(:post).with(
          'https://api.telegram.org/bot_botapitoken/sendMessage',
          {
            :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded' },
            :body     => form_data.sub('STATUS', 'Success'),
            :expects  => 200
          }
        )

        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'sends a warning message' do
        Excon.expects(:post).with(
          'https://api.telegram.org/bot_botapitoken/sendMessage',
          {
            :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded' },
            :body     => form_data.sub('STATUS', 'Warning'),
            :expects  => 200
          }
        )

        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'sends a failure message' do
        Excon.expects(:post).with(
          'https://api.telegram.org/bot_botapitoken/sendMessage',
          {
            :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded' },
            :body     => form_data.sub('STATUS', 'Failure'),
            :expects  => 200
          }
        )

        notifier.send(:notify!, :failure)
      end
    end

  end # describe '#notify!'

end
end
