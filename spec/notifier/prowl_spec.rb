# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Notifier::Prowl do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:notifier) { Notifier::Prowl.new(model) }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Notifier::Base'

  describe '#initialize' do
    it 'provides default values' do
      expect( notifier.application  ).to be_nil
      expect( notifier.api_key      ).to be_nil

      expect( notifier.on_success     ).to be(true)
      expect( notifier.on_warning     ).to be(true)
      expect( notifier.on_failure     ).to be(true)
      expect( notifier.max_retries    ).to be(10)
      expect( notifier.retry_waitsec  ).to be(30)
    end

    it 'configures the notifier' do
      notifier = Notifier::Prowl.new(model) do |prowl|
        prowl.application = 'my_app'
        prowl.api_key     = 'my_api_key'

        prowl.on_success    = false
        prowl.on_warning    = false
        prowl.on_failure    = false
        prowl.max_retries   = 5
        prowl.retry_waitsec = 10
      end

      expect( notifier.application  ).to eq 'my_app'
      expect( notifier.api_key      ).to eq 'my_api_key'

      expect( notifier.on_success     ).to be(false)
      expect( notifier.on_warning     ).to be(false)
      expect( notifier.on_failure     ).to be(false)
      expect( notifier.max_retries    ).to be(5)
      expect( notifier.retry_waitsec  ).to be(10)
    end
  end # describe '#initialize'

  describe '#notify!' do
    let(:notifier) {
      Notifier::Prowl.new(model) do |prowl|
        prowl.application = 'my_app'
        prowl.api_key = 'my_api_key'
      end
    }
    let(:form_data) {
      'apikey=my_api_key&application=my_app&' +
      'description=test+label+%28test_trigger%29&' +
      'event=%5BBackup%3A%3A' + 'STATUS' + '%5D'
    }

    context 'when status is :success' do
      it 'sends a success message' do
        Excon.expects(:post).with(
          'https://api.prowlapp.com/publicapi/add',
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
          'https://api.prowlapp.com/publicapi/add',
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
          'https://api.prowlapp.com/publicapi/add',
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
