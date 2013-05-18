# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Notifier::Pushover do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:notifier) { Notifier::Pushover.new(model) }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Notifier::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( notifier.user     ).to be_nil
      expect( notifier.token    ).to be_nil
      expect( notifier.device   ).to be_nil
      expect( notifier.title    ).to be_nil
      expect( notifier.priority ).to be_nil

      expect( notifier.on_success     ).to be(true)
      expect( notifier.on_warning     ).to be(true)
      expect( notifier.on_failure     ).to be(true)
      expect( notifier.max_retries    ).to be(10)
      expect( notifier.retry_waitsec  ).to be(30)
    end

    it 'configures the notifier' do
      notifier = Notifier::Pushover.new(model) do |pushover|
        pushover.user     = 'my_user'
        pushover.token    = 'my_token'
        pushover.device   = 'my_device'
        pushover.title    = 'my_title'
        pushover.priority = 'my_priority'

        pushover.on_success     = false
        pushover.on_warning     = false
        pushover.on_failure     = false
        pushover.max_retries    = 5
        pushover.retry_waitsec  = 10
      end

      expect( notifier.user     ).to eq 'my_user'
      expect( notifier.token    ).to eq 'my_token'
      expect( notifier.device   ).to eq 'my_device'
      expect( notifier.title    ).to eq 'my_title'
      expect( notifier.priority ).to eq 'my_priority'

      expect( notifier.on_success     ).to be(false)
      expect( notifier.on_warning     ).to be(false)
      expect( notifier.on_failure     ).to be(false)
      expect( notifier.max_retries    ).to be(5)
      expect( notifier.retry_waitsec  ).to be(10)
    end
  end # describe '#initialize'

  describe '#notify!' do
    let(:notifier) {
      Notifier::Pushover.new(model) do |pushover|
        pushover.user     = 'my_user'
        pushover.token    = 'my_token'
      end
    }
    let(:form_data) {
      'message=%5BBackup%3A%3A' + 'STATUS' +
      '%5D+test+label+%28test_trigger%29&token=my_token&user=my_user'
    }

    context 'when status is :success' do
      it 'sends a success message' do
        Excon.expects(:post).with(
          'https://api.pushover.net/1/messages.json',
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
          'https://api.pushover.net/1/messages.json',
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
          'https://api.pushover.net/1/messages.json',
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
        Notifier::Pushover.new(model) do |pushover|
          pushover.user     = 'my_user'
          pushover.token    = 'my_token'
          pushover.device   = 'my_device'
          pushover.title    = 'my_title'
          pushover.priority = 'my_priority'
        end
      }
      let(:form_data) {
        'device=my_device&message=%5BBackup%3A%3ASuccess' +
        '%5D+test+label+%28test_trigger%29&priority=my_priority' +
        '&title=my_title&token=my_token&user=my_user'
      }

      it 'sends message with optional parameters' do
        Excon.expects(:post).with(
          'https://api.pushover.net/1/messages.json',
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
