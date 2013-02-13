# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::PostRequest do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) do
    Backup::Notifier::PostRequest.new(model) do |notifier|
      notifier.host  = 'http://host.com'
      notifier.token = 'token'
    end
  end

  it 'should be a subclass of Notifier::Base' do
    Backup::Notifier::PostRequest.
      superclass.should == Backup::Notifier::Base
  end

  describe '#initialize' do
    after { Backup::Notifier::PostRequest.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Notifier::PostRequest.any_instance.expects(:load_defaults!)
      notifier
    end

    it 'should pass the model reference to Base' do
      notifier.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        notifier.host.should       == 'http://host.com'
        notifier.token.should      == 'token'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end

      it 'should use default values if none are given' do
        notifier = Backup::Notifier::PostRequest.new(model)
        notifier.token.should      be_nil
        notifier.host.should       be_nil

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Notifier::PostRequest.defaults do |n|
          n.token          = 'the_token'
          n.host           = 'http://anotherhost.com'
          n.on_failure     = false
        end
      end

      it 'should use pre-configured defaults' do
        notifier = Backup::Notifier::PostRequest.new(model)

        notifier.token.should      == 'the_token'
        notifier.host.should       == 'http://anotherhost.com'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == false
      end

      it 'should override pre-configured defaults' do
        notifier = Backup::Notifier::PostRequest.new(model) do |n|
          n.token          = 'new_token'
          n.host           = 'http://testhost.com'
          n.on_success     = false
          n.on_failure     = true
        end

        notifier.token.should          == 'new_token'
        notifier.host.should           == 'http://testhost.com'

        notifier.on_success.should     == false
        notifier.on_warning.should     == true
        notifier.on_failure.should     == true
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  # Can't really test this area without a working host
  # 
  # describe '#notify!' do
  #   context 'when status is :success' do
  #     it 'should send Success message' do
  #       notifier.expects(:send_message).with(
  #         '[Backup::Success] test label (test_trigger)'
  #       )
  #       notifier.send(:notify!, :success)
  #     end
  #   end

  #   context 'when status is :warning' do
  #     it 'should send Warning message' do
  #       notifier.expects(:send_message).with(
  #         '[Backup::Warning] test label (test_trigger)'
  #       )
  #       notifier.send(:notify!, :warning)
  #     end
  #   end

  #   context 'when status is :failure' do
  #     it 'should send Failure message' do
  #       notifier.expects(:send_message).with(
  #         '[Backup::Failure] test label (test_trigger)'
  #       )
  #       notifier.send(:notify!, :failure)
  #     end
  #   end
  # end # describe '#notify!'
end
