# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Notifier::Nagios do
  before do
    Notifier::Nagios.any_instance.stubs(:utility).with(:send_nsca).returns('send_nsca')
    Notifier::Nagios.any_instance.stubs(:utility).with(:hostname).returns('hostname')
    Notifier::Nagios.any_instance.stubs(:run).with('hostname').returns("foobar.baz\n")
  end

  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:notifier) { Notifier::Nagios.new(model) }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Notifier::Base'

  describe '#initialize' do
    after { Notifier::Nagios.clear_defaults! }

    it 'loads pre-configured defaults through Base' do
      Notifier::Nagios.any_instance.expects(:load_defaults!)
      notifier
    end

    it 'passes the model reference to Base' do
      notifier.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      it 'uses the default values' do
        notifier.nagios_host.should  == 'foobar.baz'
        notifier.nagios_port.should  == 5667
        notifier.service_name.should == 'Backup test_trigger'
        notifier.service_host.should == 'foobar.baz'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Notifier::Nagios.defaults do |n|
          n.nagios_host  = 'somehost'
          n.nagios_port  = 9876
          n.service_name = 'Awesome Backup'
          n.service_host = 'awesome.box'

          n.on_success = false
          n.on_warning = false
          n.on_failure = false
        end
      end

      it 'uses the pre-configured defaults' do
        notifier = Notifier::Nagios.new(model)
        notifier.nagios_host.should == 'somehost'
        notifier.nagios_port.should == 9876
        notifier.service_name.should == 'Awesome Backup'
        notifier.service_host.should == 'awesome.box'

        notifier.on_success.should == false
        notifier.on_warning.should == false
        notifier.on_failure.should == false
      end

      it 'overrides the pre-configured defaults' do
        notifier = Notifier::Nagios.new(model) do |n|
          n.nagios_host  = 'nagios2'
          n.nagios_port  = 7788
          n.service_name = 'New Backup'
          n.service_host = 'newhost'

          n.on_success = false
          n.on_warning = true
          n.on_failure = true
        end

        notifier.nagios_host.should  == 'nagios2'
        notifier.nagios_port.should  == 7788
        notifier.service_name.should == 'New Backup'
        notifier.service_host.should == 'newhost'

        notifier.on_success.should == false
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#notify!' do
    before(:each) do
      model.perform!
    end

    context 'when status is :success' do
      it 'sends a Success message' do
        notifier.expects(:send_message).with("Completed successfully in #{model.duration}")
        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'sends a Warning message' do
        notifier.expects(:send_message).with("Completed successfully with warnings in #{model.duration}")
        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'sends a Failure message' do
        notifier.expects(:send_message).with("Failed in #{model.duration}")
        notifier.send(:notify!, :failure)
      end
    end
  end # describe '#notify!'

  describe '#send_message' do
    it 'sends the check to the given port' do
      notifier.expects(:run).with(
        "echo 'foobar.baz\tBackup test_trigger\t1\tNot sure this worked...' | send_nsca -H 'foobar.baz' -p '5555'"
      )

      model.instance_variable_set(:@exit_status, 1)
      notifier.nagios_port = 5555
      notifier.send(:send_message, 'Not sure this worked...')
    end
  end

end
end
