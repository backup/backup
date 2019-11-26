require "spec_helper"

module Backup
  describe Notifier::PagerDuty do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:notifier) { Notifier::PagerDuty.new(model) }

    describe "#initialize" do
      it "has sensible defaults" do
        expect(notifier.service_key).to be_nil
        expect(notifier.resolve_on_warning).to eq(false)
      end

      it "yields to allow modifying defaults" do
        notifier = Notifier::PagerDuty.new(model) do |pd|
          pd.service_key = "foobar"
        end

        expect(notifier.service_key).to eq("foobar")
      end
    end

    describe "notify!" do
      let(:pagerduty) { double }
      let(:incident) { double }

      let(:incident_key) { "backup/test_trigger" }
      let(:incident_details) do
        {
          incident_key: incident_key,
          details: {
            trigger: "test_trigger",
            label: "test label",
            started_at: nil,
            finished_at: nil,
            duration: nil,
            exception: nil
          }
        }
      end

      before do
        allow(notifier).to receive(:pagerduty).and_return(pagerduty)
      end

      it "resolves an incident when status is :success" do
        incident_details[:details][:status] = :success

        expect(pagerduty).to receive(:get_incident).with(incident_key).and_return(incident)
        expect(incident).to receive(:resolve).with("Backup - test label", incident_details)

        notifier.send(:notify!, :success)
      end

      it "triggers an incident when status is :warning and resolve_on_warning is false" do
        incident_details[:details][:status] = :warning
        expect(pagerduty).to receive(:trigger).with("Backup - test label", incident_details)

        notifier.send(:notify!, :warning)
      end

      it "resolves an incident when status is :warning and resolve_on_warning is true" do
        notifier.resolve_on_warning = true

        incident_details[:details][:status] = :warning

        expect(pagerduty).to receive(:get_incident).with(incident_key).and_return(incident)
        expect(incident).to receive(:resolve).with("Backup - test label", incident_details)

        notifier.send(:notify!, :warning)
      end

      it "triggers an incident when status is :failure" do
        incident_details[:details][:status] = :failure
        expect(pagerduty).to receive(:trigger).with("Backup - test label", incident_details)

        notifier.send(:notify!, :failure)
      end
    end
  end
end
