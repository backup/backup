# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Notifier::Sendmail do
  let(:notifier) do
    Backup::Notifier::Sendmail.new do |mail|
      mail.from                 = 'my.sender.email@gmail.com'
      mail.to                   = 'my.receiver.email@gmail.com'
    end
  end

  it do
    notifier.from.should                 == 'my.sender.email@gmail.com'
    notifier.to.should                   == 'my.receiver.email@gmail.com'

    notifier.on_success.should == true
    notifier.on_failure.should == true
  end

  describe 'defaults' do
    it do
      Backup::Configuration::Notifier::Sendmail.defaults do |mail|
        mail.to         = 'some.receiver.email@gmail.com'
        mail.on_success = false
        mail.on_failure = true
      end
      notifier = Backup::Notifier::Sendmail.new do |mail|
        mail.from = 'my.sender.email@gmail.com'
      end

      notifier.to.should   == 'some.receiver.email@gmail.com'
      notifier.from.should == 'my.sender.email@gmail.com'
      notifier.on_success.should == false
      notifier.on_failure.should == true
    end
  end

  describe '#initialize' do
    it do
      Backup::Notifier::Sendmail.any_instance.expects(:set_defaults!)
      Backup::Notifier::Sendmail.new
    end
  end

  describe '#perform!' do
    let(:model) { Backup::Model.new('blah', 'blah') {} }
    before do
      notifier.on_success = false
      notifier.on_failure = false
    end

    context "when successful" do
      it do
        Backup::Logger.expects(:message).with("Backup::Notifier::Sendmail started notifying about the process.")
        notifier.expects("notify_success!")
        notifier.on_success = true
        notifier.perform!(model)
      end

      it do
        notifier.expects("notify_success!").never
        notifier.on_success = false
        notifier.perform!(model)
      end
    end

    context "when failed" do
      it do
        Backup::Logger.expects(:message).with("Backup::Notifier::Sendmail started notifying about the process.")
        notifier.expects("notify_failure!")
        notifier.on_failure = true
        notifier.perform!(model, Exception.new)
      end

      it do
        notifier.expects("notify_failure!").never
        notifier.on_failure = false
        notifier.perform!(model, Exception.new)
      end
    end
  end
end
