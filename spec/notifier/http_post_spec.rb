# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Notifier::HttpPost do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:notifier) {
    Notifier::HttpPost.new(model) do |post|
      post.uri = 'https://www.example.com/path'
    end
  }
  let(:default_form_data) {
    'message=%5BBackup%3A%3ASuccess%5D+test+label+%28test_trigger%29' +
    '&status=success'
  }
  let(:default_headers) {
    { 'User-Agent' => "Backup/#{ VERSION }",
      'Content-Type' => 'application/x-www-form-urlencoded' }
  }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Notifier::Base'

  describe '#initialize' do
    it 'provides default values' do
      notifier = Notifier::HttpPost.new(model)

      expect( notifier.uri              ).to be_nil
      expect( notifier.headers          ).to eq({})
      expect( notifier.params           ).to eq({})
      expect( notifier.success_codes    ).to be 200
      expect( notifier.ssl_verify_peer  ).to be_nil
      expect( notifier.ssl_ca_file      ).to be_nil

      expect( notifier.on_success     ).to be(true)
      expect( notifier.on_warning     ).to be(true)
      expect( notifier.on_failure     ).to be(true)
      expect( notifier.max_retries    ).to be(10)
      expect( notifier.retry_waitsec  ).to be(30)
    end

    it 'configures the notifier' do
      notifier = Notifier::HttpPost.new(model) do |post|
        post.uri              = 'my_uri'
        post.headers          = 'my_headers'
        post.params           = 'my_params'
        post.success_codes    = 'my_success_codes'
        post.ssl_verify_peer  = 'my_ssl_verify_peer'
        post.ssl_ca_file      = 'my_ssl_ca_file'

        post.on_success     = false
        post.on_warning     = false
        post.on_failure     = false
        post.max_retries    = 5
        post.retry_waitsec  = 10
      end

      expect( notifier.uri              ).to eq 'my_uri'
      expect( notifier.headers          ).to eq 'my_headers'
      expect( notifier.params           ).to eq 'my_params'
      expect( notifier.success_codes    ).to eq 'my_success_codes'
      expect( notifier.ssl_verify_peer  ).to eq 'my_ssl_verify_peer'
      expect( notifier.ssl_ca_file      ).to eq 'my_ssl_ca_file'

      expect( notifier.on_success     ).to be(false)
      expect( notifier.on_warning     ).to be(false)
      expect( notifier.on_failure     ).to be(false)
      expect( notifier.max_retries    ).to be(5)
      expect( notifier.retry_waitsec  ).to be(10)
    end
  end # describe '#initialize'

  describe '#headers' do

    it 'defines additional headers to be sent' do
      notifier.headers = { 'Authorization' => 'my_auth' }

      Excon.expects(:post).with(
        'https://www.example.com/path',
        {
          :headers  => { 'User-Agent' => "Backup/#{ VERSION }",
                         'Content-Type' => 'application/x-www-form-urlencoded',
                         'Authorization' => 'my_auth' },
          :body     => default_form_data,
          :expects  => 200
        }
      )

      notifier.send(:notify!, :success)
    end

    it 'may overrided the User-Agent header' do
      notifier.headers = { 'Authorization' => 'my_auth', 'User-Agent' => 'my_app' }

      Excon.expects(:post).with(
        'https://www.example.com/path',
        {
          :headers  => { 'User-Agent' => 'my_app',
                         'Content-Type' => 'application/x-www-form-urlencoded',
                         'Authorization' => 'my_auth' },
          :body     => default_form_data,
          :expects  => 200
        }
      )

      notifier.send(:notify!, :success)
    end

    it 'may omit the User-Agent header' do
      notifier.headers = { 'Authorization' => 'my_auth', 'User-Agent' => nil }

      Excon.expects(:post).with(
        'https://www.example.com/path',
        {
          :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded',
                         'Authorization' => 'my_auth' },
          :body     => default_form_data,
          :expects  => 200
        }
      )

      notifier.send(:notify!, :success)
    end

  end # describe '#headers'

  describe '#params' do

    it 'defines additional form parameters to be sent' do
      notifier.params = { 'my_param' => 'my_value' }
      form_data = 'message=%5BBackup%3A%3ASuccess%5D+test+label+%28test_trigger%29' +
          '&my_param=my_value&status=success'

      Excon.expects(:post).with(
        'https://www.example.com/path',
        {
          :headers  => default_headers,
          :body     => form_data,
          :expects  => 200
        }
      )

      notifier.send(:notify!, :success)
    end

    it 'may override the `message` parameter' do
      notifier.params = { 'my_param' => 'my_value', 'message' => 'my message' }
      form_data = 'message=my+message&my_param=my_value&status=success'

      Excon.expects(:post).with(
        'https://www.example.com/path',
        {
          :headers  => default_headers,
          :body     => form_data,
          :expects  => 200
        }
      )

      notifier.send(:notify!, :success)
    end

    it 'may omit the `message` parameter' do
      notifier.params = { 'my_param' => 'my_value', 'message' => nil }
      form_data = 'my_param=my_value&status=success'

      Excon.expects(:post).with(
        'https://www.example.com/path',
        {
          :headers  => default_headers,
          :body     => form_data,
          :expects  => 200
        }
      )

      notifier.send(:notify!, :success)
    end

  end # describe '#params'

  describe '#success_codes' do

    it 'specifies expected http success codes' do
      notifier.success_codes = [200, 201]

      Excon.expects(:post).with(
        'https://www.example.com/path',
        {
          :headers  => default_headers,
          :body     => default_form_data,
          :expects  => [200, 201]
        }
      )

      notifier.send(:notify!, :success)
    end
  end # describe '#success_codes'

  describe '#ssl_verify_peer' do

    it 'may force enable verification' do
      notifier.ssl_verify_peer = true

      Excon.expects(:post).with(
        'https://www.example.com/path',
        {
          :headers  => default_headers,
          :body     => default_form_data,
          :expects  => 200,
          :ssl_verify_peer => true
        }
      )

      notifier.send(:notify!, :success)
    end

    it 'may disable verification' do
      notifier.ssl_verify_peer = false

      Excon.expects(:post).with(
        'https://www.example.com/path',
        {
          :headers  => default_headers,
          :body     => default_form_data,
          :expects  => 200,
          :ssl_verify_peer => false
        }
      )

      notifier.send(:notify!, :success)
    end

  end # describe '#ssl_verify_peer'

  describe '#ssl_ca_file' do

    it 'specifies path to a custom cacert.pem file' do
      notifier.ssl_ca_file = '/my/cacert.pem'

      Excon.expects(:post).with(
        'https://www.example.com/path',
        {
          :headers  => default_headers,
          :body     => default_form_data,
          :expects  => 200,
          :ssl_ca_file => '/my/cacert.pem'
        }
      )

      notifier.send(:notify!, :success)
    end
  end # describe '#ssl_ca_file'

  describe '#notify!' do
    let(:form_data) {
      'message=%5BBackup%3A%3A' + 'TAG' +
      '%5D+test+label+%28test_trigger%29&status=' + 'STATUS'
    }

    context 'when status is :success' do
      it 'sends a success message' do
        Excon.expects(:post).with(
          'https://www.example.com/path',
          {
            :headers  => default_headers,
            :body     => form_data.sub('TAG', 'Success').sub('STATUS', 'success'),
            :expects  => 200
          }
        )

        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'sends a warning message' do
        Excon.expects(:post).with(
          'https://www.example.com/path',
          {
            :headers  => default_headers,
            :body     => form_data.sub('TAG', 'Warning').sub('STATUS', 'warning'),
            :expects  => 200
          }
        )

        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'sends a failure message' do
        Excon.expects(:post).with(
          'https://www.example.com/path',
          {
            :headers  => default_headers,
            :body     => form_data.sub('TAG', 'Failure').sub('STATUS', 'failure'),
            :expects  => 200
          }
        )

        notifier.send(:notify!, :failure)
      end
    end

  end # describe '#notify!'

end
end
