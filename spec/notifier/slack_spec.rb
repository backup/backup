# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Notifier::Slack do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:notifier) { Notifier::Slack.new(model) }

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Notifier::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( notifier.team     ).to be_nil
      expect( notifier.token    ).to be_nil
      expect( notifier.channel  ).to be_nil
      expect( notifier.username ).to be_nil

      expect( notifier.on_success     ).to be(true)
      expect( notifier.on_warning     ).to be(true)
      expect( notifier.on_failure     ).to be(true)
      expect( notifier.max_retries    ).to be(10)
      expect( notifier.retry_waitsec  ).to be(30)
    end

    it 'configures the notifier' do
      notifier = Notifier::Slack.new(model) do |slack|
        slack.team     = 'my_team'
        slack.token    = 'my_token'
        slack.channel  = 'my_channel'
        slack.username = 'my_username'

        slack.on_success     = false
        slack.on_warning     = false
        slack.on_failure     = false
        slack.max_retries    = 5
        slack.retry_waitsec  = 10
      end


      expect( notifier.team     ).to eq 'my_team'
      expect( notifier.token    ).to eq 'my_token'
      expect( notifier.channel  ).to eq 'my_channel'
      expect( notifier.username ).to eq 'my_username'

      expect( notifier.on_success     ).to be(false)
      expect( notifier.on_warning     ).to be(false)
      expect( notifier.on_failure     ).to be(false)
      expect( notifier.max_retries    ).to be(5)
      expect( notifier.retry_waitsec  ).to be(10)
    end
  end # describe '#initialize'

  describe '#notify!' do
    let(:notifier) {
      Notifier::Slack.new(model) do |slack|
        slack.team     = 'my_team'
        slack.token    = 'my_token'
      end
    }
    let(:form_data) {
      'payload=%7B%22text%22%3A%22%5BBackup%3A%3A' + 'STATUS' + '%5D+test+label+%28test_trigger%29%22%7D'
    }
    let(:url) {
      'https://my_team.slack.com/services/hooks/incoming-webhook?token=my_token'
    }

    context 'when status is :success' do
      it 'sends a success message' do
        Excon.expects(:post).with(
          url,
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
          url,
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
          url,
          {
            :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded' },
            :body     => form_data.sub('STATUS', 'Failure'),
            :expects  => 200
          }
        )

        notifier.send(:notify!, :failure)
      end
    end

    context 'when optional parameters are provided' do
      let(:notifier) {
        Notifier::Slack.new(model) do |slack|
          slack.team     = 'my_team'
          slack.token    = 'my_token'
          slack.channel  = 'my_channel'
          slack.username = 'my_username'
        end
      }
      let(:form_data) {
        'payload=%7B%22' +
        'text%22%3A%22%5BBackup%3A%3ASuccess%5D+test+label+%28test_trigger%29%22%2C%22' +
        'channel%22%3A%22my_channel%22%2C%22username%22%3A%22my_username%22%7D'
      }
      let(:url) {
        'https://my_team.slack.com/services/hooks/incoming-webhook?token=my_token'
      }

      it 'sends message with optional parameters' do
        Excon.expects(:post).with(
          url,
          {
            :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded' },
            :body     => form_data,
            :expects  => 200
          }
        )

        notifier.send(:notify!, :success)
      end
    end

  end # describe '#notify!'

end
end
