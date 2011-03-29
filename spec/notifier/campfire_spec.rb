# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Notifier::Campfire do
  let(:notifier) do
    Backup::Notifier::Campfire.new do |campfire|
      campfire.token     = 'token'
      campfire.subdomain = 'subdomain'
      campfire.room_id   = 'room_id'
    end
  end

  it do
    notifier.token.should     == 'token'
    notifier.subdomain.should == 'subdomain'
    notifier.room_id.should   == 'room_id'

    notifier.on_success.should == true
    notifier.on_failure.should == true
  end

  describe 'defaults' do
    it do
      Backup::Configuration::Notifier::Campfire.defaults do |twitter|
        twitter.token      = 'old_token'
        twitter.on_success = false
        twitter.on_failure = true
      end
        notifier      = Backup::Notifier::Campfire.new do |twitter|
        twitter.token = 'new_token'
      end

      notifier.token.should      == 'new_token'
      notifier.on_success.should == false
      notifier.on_failure.should == true
    end
  end

  describe '#initialize' do
    it do
      Backup::Notifier::Campfire.any_instance.expects(:set_defaults!)
      Backup::Notifier::Campfire.new
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
        Backup::Logger.expects(:message).with("Backup::Notifier::Campfire started notifying about the process.")
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
        Backup::Logger.expects(:message).with("Backup::Notifier::Campfire started notifying about the process.")
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

  describe Backup::Notifier::Campfire::Interface do
    let(:room) do
      Backup::Notifier::Campfire::Room.new('room_id', 'subdomain', 'token')
    end

    it do
      room.token.should     == 'token'
      room.subdomain.should == 'subdomain'
      room.room_id.should   == 'room_id'
    end
  end
end
