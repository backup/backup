# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Nagios do
  before do
    Backup::Notifier::Nagios.any_instance.stubs(:utility).with(:send_nsca).returns('send_nsca')
    Backup::Notifier::Nagios.any_instance.stubs(:utility).with(:hostname).returns('hostname')
    Backup::Notifier::Nagios.any_instance.stubs(:run).with('hostname').returns("foobar.baz\n")
  end

  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) do
    Backup::Notifier::Nagios.new(model) do |nagios|
      nagios.nagios_host  = 'monitor.box'
      nagios.nagios_port  = 1234
      nagios.service_name = 'Database Backup'
      nagios.service_host = 'db.box'
    end
  end
  let(:s) { sequence '' }

  it 'should be a subclass of Notifier::Base' do
    Backup::Notifier::Nagios.
      superclass.should == Backup::Notifier::Base
  end

  describe '#initialize' do
    after { Backup::Notifier::Nagios.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Notifier::Nagios.any_instance.expects(:load_defaults!)
      notifier
    end

    it 'should pass the model reference to Base' do
      notifier.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        notifier.nagios_host.should  == 'monitor.box'
        notifier.nagios_port.should  == 1234
        notifier.service_name.should == 'Database Backup'
        notifier.service_host.should == 'db.box'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end

      it 'should use default values if none are given' do
        notifier = Backup::Notifier::Nagios.new(model)
        notifier.nagios_host.should  == 'localhost'
        notifier.nagios_port.should  == 5667
        notifier.service_name.should == 'Backup'
        notifier.service_host.should == 'foobar.baz'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Notifier::Nagios.defaults do |n|
          n.nagios_host  = 'somehost'
          n.nagios_port  = 9876
          n.service_name = 'Awesome Backup'
          n.service_host = 'awesome.box'

          n.on_success = false
          n.on_warning = false
          n.on_failure = false
        end
      end

      it 'should use pre-configured defaults' do
        notifier = Backup::Notifier::Nagios.new(model)
        notifier.nagios_host.should == 'somehost'
        notifier.nagios_port.should == 9876
        notifier.service_name.should == 'Awesome Backup'
        notifier.service_host.should == 'awesome.box'

        notifier.on_success.should == false
        notifier.on_warning.should == false
        notifier.on_failure.should == false
      end

      it 'should override pre-configured defaults' do
        notifier = Backup::Notifier::Nagios.new(model) do |n|
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
      it 'should send Success message' do
        notifier.expects(:send_message).with("Completed successfully")
        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'should send Warning message' do
        notifier.expects(:send_message).with("Completed successfully with warnings")
        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'should send Failure message' do
        notifier.expects(:send_message).with("Failed")
        notifier.send(:notify!, :failure)
      end
    end
  end # describe '#notify!'

  describe '#send_message' do
    it 'sends the check to the given port' do
      notifier.expects(:run).in_sequence(s).with(
        "echo 'db.box\tDatabase Backup\t1\tNot sure this worked...' | send_nsca -H 'monitor.box' -p '5555'"
      )

      model.instance_variable_set(:@exit_status, 1)
      notifier.nagios_port = 5555
      notifier.send(:send_message, 'Not sure this worked...')
    end
  end

end
