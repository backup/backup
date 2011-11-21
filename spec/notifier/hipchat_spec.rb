# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Notifier::Hipchat do
  let(:notifier) do
    Backup::Notifier::Hipchat.new do |hc|
      hc.from = 'application'
      hc.token = 'token'
      hc.rooms_notified = ['room1']
    end
  end

  it "has the correct defaults" do
    notifier.from.should == 'application'
    notifier.token.should == 'token'
    notifier.on_success.should == true
    notifier.on_failure.should == true
  end

  describe 'defaults' do
    it do
      Backup::Configuration::Notifier::Hipchat.defaults do |hc|
        hc.token = 'old'
        hc.from = 'before'
      end
      notifier = Backup::Notifier::Hipchat.new do |hc|
        hc.token = 'new'
        hc.from = 'after'
      end

      notifier.token.should == 'new'
      notifier.from.should == 'after'
    end
  end

  describe '#initialize' do
    it do
      Backup::Notifier::Hipchat.any_instance.expects(:set_defaults!)
      Backup::Notifier::Hipchat.new
    end
  end

  describe '#perform!' do
    let(:model) { Backup::Model.new('foo', 'bar') {} }
    before do
      notifier.on_success = false
      notifier.on_failure = false
    end

    context "when successful" do
      it do
        Backup::Logger.expects(:message).with("Backup::Notifier::Hipchat started notifying about the process.")
        notifier.expects(:notify_success!)
        notifier.on_success = true
        notifier.perform!(model)
      end

      it do
        notifier.expects(:notify_success!).never
        notifier.on_success = false
        notifier.perform!(model)
      end
    end

    context "when failed" do
      it do
        notifier.expects(:notify_failure!)
        notifier.on_failure = true
        notifier.perform!(model, Exception.new)
      end

      it do
        notifier.expects(:notifier_failure!).never
        notifier.on_failure = false
        notifier.perform!(model, Exception.new)
      end
    end

    context "hipchat" do
      it "sends to rooms" do
        rooms = [ "red_room", "blue_room" ]
        notifier = Backup::Notifier::Hipchat.new do |notifier|
          notifier.rooms_notified = rooms
          notifier.on_success = true
          notifier.from = 'application'
        end

        hipchat_mock = mock()
        hipchat_mock.expects(:send).times(2).with {|user, message, hash|
          user.should == 'application'
          hash[:color].should == 'yellow'
          hash[:notify].should be_nil
        }

        HipChat::Client.any_instance.expects(:[]).times(2).with {|i| rooms.include? i}.returns(hipchat_mock)

        notifier.perform!(model)
      end

      it "sends with colors on success" do
        notifier = Backup::Notifier::Hipchat.new do |notifier|
          notifier.on_success = true
          notifier.from = 'application'
          notifier.success_color = 'green'
          notifier.failure_color = 'red'
          notifier.rooms_notified = ['room1']
        end

        hipchat_mock = mock()
        hipchat_mock.expects(:send).with {|user, message, hash|
          hash[:color].should == 'green'
        }

        HipChat::Client.any_instance.expects(:[]).returns(hipchat_mock)
        notifier.perform!(model)
      end
    end

    it "sends with colors on failure" do
        notifier = Backup::Notifier::Hipchat.new do |notifier|
          notifier.on_success = true
          notifier.on_failure = true
          notifier.from = 'application'
          notifier.success_color = 'green'
          notifier.failure_color = 'red'
          notifier.rooms_notified = ['room1']
        end

        hipchat_mock = mock()
        hipchat_mock.expects(:send).with {|user, message, hash|
          hash[:color].should == 'red'
        }

        HipChat::Client.any_instance.expects(:[]).returns(hipchat_mock)
        notifier.perform!(model, Exception.new)
    end

    it "will convert a single room param to an array" do
      notifier = Backup::Notifier::Hipchat.new do |notifier|
        notifier.from = 'application'
        notifier.token = 'token'
        notifier.rooms_notified = 'room1'
      end

      HipChat::Client.any_instance.expects(:[]).returns(stub(:send))

      notifier.perform!(model)
      notifier.instance_variable_get("@rooms_notified").should be_a_kind_of Array
    end
  end
end
