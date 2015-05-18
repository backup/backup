# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Notifier::Command do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:notifier) {
    Notifier::Command.new(model) do |cmd|
      cmd.command = 'notify-send'
      cmd.args    = [
        ->(model, status) { model.label.upcase },
        "%V | %t"
      ]
    end
  }

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Notifier::Base'

  describe '#initialize' do
    it 'provides default values' do
      notifier = Notifier::Command.new(model)
      expect( notifier.command ).to be_nil
      expect( notifier.args    ).to eq( ["%L %v"] )
    end

    it 'configures the notifier' do
      notifier = Notifier::Command.new(model) do |cmd|
        cmd.command = 'my_command'
        cmd.args    = 'my_args'
      end

      expect( notifier.command ).to eq 'my_command'
      expect( notifier.args    ).to eq 'my_args'
    end
  end # describe '#initialize'


  describe '#notify!' do
    context 'when status is :success' do
      it 'sends a success message' do
        IO.expects(:popen).with(
          [
            "notify-send",
            "TEST LABEL",
            "Succeeded | test_trigger"
          ]
        )

        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'sends a warning message' do
        IO.expects(:popen).with(
          [
            "notify-send",
            "TEST LABEL",
            "Succeeded with warnings | test_trigger"
          ]
        )

        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'sends a failure message' do
        IO.expects(:popen).with(
          [
            "notify-send",
            "TEST LABEL",
            "Failed | test_trigger"
          ]
        )

        notifier.send(:notify!, :failure)
      end
    end
  end # describe '#notify!'

end
end
