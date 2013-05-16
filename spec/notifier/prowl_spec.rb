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

      expect( notifier.on_success ).to be(true)
      expect( notifier.on_warning ).to be(true)
      expect( notifier.on_failure ).to be(true)
    end

    it 'configures the notifier' do
      notifier = Notifier::Prowl.new(model) do |prowl|
        prowl.application = 'my_app'
        prowl.api_key     = 'my_api_key'

        prowl.on_success = false
        prowl.on_warning = false
        prowl.on_failure = false
      end

      expect( notifier.application  ).to eq 'my_app'
      expect( notifier.api_key      ).to eq 'my_api_key'

      expect( notifier.on_success ).to be(false)
      expect( notifier.on_warning ).to be(false)
      expect( notifier.on_failure ).to be(false)
    end
  end # describe '#initialize'

  describe '#notify!' do
    let(:notifier) {
      Notifier::Prowl.new(model) do |prowl|
        prowl.application = 'my_app'
        prowl.api_key = 'my_api_key'
      end
    }
    let(:client) { mock }
    let(:message) { '[Backup::%s]' }

    context 'when status is :success' do
      it 'sends a success message' do
        Prowler.expects(:new).
            with(:application => 'my_app', :api_key => 'my_api_key').
            returns(client)
        client.expects(:notify).
            with(message % 'Success', 'test label (test_trigger)')

        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'sends a warning message' do
        Prowler.expects(:new).
            with(:application => 'my_app', :api_key => 'my_api_key').
            returns(client)
        client.expects(:notify).
            with(message % 'Warning', 'test label (test_trigger)')

        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'sends a failure message' do
        Prowler.expects(:new).
            with(:application => 'my_app', :api_key => 'my_api_key').
            returns(client)
        client.expects(:notify).
            with(message % 'Failure', 'test label (test_trigger)')

        notifier.send(:notify!, :failure)
      end
    end

  end # describe '#notify!'

end
end
