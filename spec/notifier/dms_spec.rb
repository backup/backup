# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::DMS do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) do
    Backup::Notifier::DMS.new(model) do |dms|
      dms.snitch_url = 'https://nosnch.test/token'
    end
  end

  it 'should be a subclass of Notifier::Base' do
    Backup::Notifier::DMS.
      superclass.should == Backup::Notifier::Base
  end

  describe '#initialize' do
    after { Backup::Notifier::DMS.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Notifier::DMS.any_instance.expects(:load_defaults!)
      notifier
    end

    it 'should pass the model reference to Base' do
      notifier.instance_variable_get(:@model).should == model
    end

    it "should use the specified snitch_url" do
      notifier.snitch_url.should eql('https://nosnch.test/token')
    end

    it "should set on_success to true" do
      notifier.on_success.should be_true
    end

    it "should not allow overriding on_success" do
      notifier = Backup::Notifier::DMS.new(model) do |dms|
        dms.on_success = false
      end

      notifier.on_success.should be_true
    end

    it "should set on_warning to true" do
      notifier.on_warning.should be_true
    end

    it "should not allow overriding on_warning" do
      notifier = Backup::Notifier::DMS.new(model) do |dms|
        dms.on_warning = false
      end

      notifier.on_warning.should be_true
    end

    it "should set on_failure to false" do
      notifier.on_failure.should be_false
    end

    it "should not allow overriding on_failure" do
      notifier = Backup::Notifier::DMS.new(model) do |dms|
        dms.on_failure = false
      end

      notifier.on_failure.should be_false
    end
  end # describe '#initialize'

  describe '#notify!' do
    it "should execute the command" do
      model.stubs(:elapsed_time).returns('00:12:23')

      notifier.expects(:'`').with("curl -d 'm=00:12:23' https://nosnch.test/token")

      notifier.send(:notify!, :success)
    end
  end # describe '#notify!'
end
