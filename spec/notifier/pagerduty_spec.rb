# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Notifier::PagerDuty do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:notifier) { Notifier::PagerDuty.new(model) }

  describe '#initialize' do
    it 'has sensible defaults' do
      expect(notifier.service_key).to be_nil
      expect(notifier.resolve_on_warning).to be_false
    end

    it 'yields to allow modifying defaults' do
      notifier = Notifier::PagerDuty.new(model) do |pd|
        pd.service_key = 'foobar'
      end

      expect(notifier.service_key).to eq('foobar')
    end
  end

  describe 'notify!' do
    let(:pagerduty) { mock }
    let(:incident) { mock }

    let(:incident_key) { 'backup/test_trigger' }
    let(:incident_details) {
      {
        :incident_key => incident_key,
        :details => {
          :trigger => 'test_trigger',
          :label => 'test label',
          :started_at => nil,
          :finished_at => nil,
          :duration => nil,
          :exception => nil
        }
      }
    }

    before do
      notifier.stubs(:pagerduty).returns(pagerduty)
    end

    it 'resolves an incident when status is :success' do
      incident_details[:details].merge!(:status => :success)

      pagerduty.expects(:get_incident).with(incident_key).returns(incident)
      incident.expects(:resolve).with('Backup - test label', incident_details)

      notifier.send(:notify!, :success)
    end

    it 'triggers an incident when status is :warning and resolve_on_warning is false' do
      incident_details[:details].merge!(:status => :warning)
      pagerduty.expects(:trigger).with('Backup - test label', incident_details)

      notifier.send(:notify!, :warning)
    end

    it 'resolves an incident when status is :warning and resolve_on_warning is true' do
      notifier.resolve_on_warning = true

      incident_details[:details].merge!(:status => :warning)

      pagerduty.expects(:get_incident).with(incident_key).returns(incident)
      incident.expects(:resolve).with('Backup - test label', incident_details)

      notifier.send(:notify!, :warning)
    end

    it 'triggers an incident when status is :failure' do
      incident_details[:details].merge!(:status => :failure)
      pagerduty.expects(:trigger).with('Backup - test label', incident_details)

      notifier.send(:notify!, :failure)
    end
  end
end
end
