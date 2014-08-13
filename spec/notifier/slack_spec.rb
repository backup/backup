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
      expect( notifier.team       ).to be_nil
      expect( notifier.token      ).to be_nil
      expect( notifier.channel    ).to be_nil
      expect( notifier.username   ).to be_nil
      expect( notifier.icon_emoji ).to eq(':floppy_disk:')

      expect( notifier.on_success    ).to be(true)
      expect( notifier.on_warning    ).to be(true)
      expect( notifier.on_failure    ).to be(true)
      expect( notifier.max_retries   ).to be(10)
      expect( notifier.retry_waitsec ).to be(30)
    end

    it 'configures the notifier' do
      notifier = Notifier::Slack.new(model) do |slack|
        slack.team       = 'my_team'
        slack.token      = 'my_token'
        slack.channel    = 'my_channel'
        slack.username   = 'my_username'
        slack.icon_emoji = ':vhs:'

        slack.on_success     = false
        slack.on_warning     = false
        slack.on_failure     = false
        slack.max_retries    = 5
        slack.retry_waitsec  = 10
      end


      expect( notifier.team       ).to eq 'my_team'
      expect( notifier.token      ).to eq 'my_token'
      expect( notifier.channel    ).to eq 'my_channel'
      expect( notifier.username   ).to eq 'my_username'
      expect( notifier.icon_emoji ).to eq ':vhs:'

      expect( notifier.on_success     ).to be(false)
      expect( notifier.on_warning     ).to be(false)
      expect( notifier.on_failure     ).to be(false)
      expect( notifier.max_retries    ).to be(5)
      expect( notifier.retry_waitsec  ).to be(10)
    end
  end # describe '#initialize'

  describe '#notify!' do
    def expected_excon_params(_url, options, expected_payload, send_log = false)
      body        = Hash[URI.decode_www_form(options[:body])]
      payload     = JSON.parse(body["payload"])
      attachments = payload["attachments"]
      fields      = attachments.first["fields"]
      titles      = fields.map { |h| h["title"] }

      result   = _url == url
      result &&= options[:headers] == { 'Content-Type' => 'application/x-www-form-urlencoded' }
      result &&= options[:expects] == 200
      result &&= attachments.size  == 1
      result &&= titles            == send_log ? expected_titles_with_log : expected_titles
      expected_payload.each do |k, v|
        result &&= payload[k.to_s] == v
      end

      result
    end

    let(:expected_titles) {
      ["Job", "Started", "Finished", "Duration", "Version"]
    }

    let(:expected_titles_with_log) {
      expected_titles += ["Detailed Backup Log"]
    }

    let(:notifier) {
      Notifier::Slack.new(model) do |slack|
        slack.team     = 'my_team'
        slack.token    = 'my_token'
      end
    }

    let(:url) {
      'https://my_team.slack.com/services/hooks/incoming-webhook?token=my_token'
    }

    context 'when status is :success' do
      it 'sends a success message' do
        Excon.expects(:post).with() do |_url, options|
          expected_excon_params(_url, options, {:text => "[Backup::Success] test label (test_trigger)"})
        end

        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'sends a warning message' do
        Excon.expects(:post).with() do |_url, options|
          expected_excon_params(_url, options, {:text => "[Backup::Warning] test label (test_trigger)"}, true)
        end

        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'sends a failure message' do
        Excon.expects(:post).with() do |_url, options|
          expected_excon_params(_url, options, {:text => "[Backup::Failure] test label (test_trigger)"}, true)
        end

        notifier.send(:notify!, :failure)
      end
    end

    context 'when optional parameters are provided' do
      let(:notifier) {
        Notifier::Slack.new(model) do |slack|
          slack.team       = 'my_team'
          slack.token      = 'my_token'
          slack.channel    = 'my_channel'
          slack.username   = 'my_username'
          slack.icon_emoji = ':vhs:'
        end
      }

      it 'sends message with optional parameters' do
        Excon.expects(:post).with() do |_url, options|
          expected_excon_params(_url, options, {
            :text       => "[Backup::Success] test label (test_trigger)",
            :channel    => 'my_channel',
            :username   => 'my_username',
            :icon_emoji => ':vhs:'
          })
        end

        notifier.send(:notify!, :success)
      end
    end

  end # describe '#notify!'

end
end
