# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
  describe Notifier::IRC do
    let(:model) { Model.new(:test_trigger, 'test label') }
    let(:notifier) { Notifier::IRC.new(model) }

    it_behaves_like 'a class that includes Configuration::Helpers'
    it_behaves_like 'a subclass of Notifier::Base'

    describe '#initialize' do
      it 'provides default values' do
        expect( notifier.channel ).to be_nil

        expect( notifier.nick    ).to eq 'backup'
        expect( notifier.port    ).to be(6667)
        expect( notifier.ssl     ).to be(0)
        expect( notifier.server  ).to eq 'irc.oftc.net'
      end

      it 'configures the notifier' do
        notifier = Notifier::IRC.new(model) do |irc|
          irc.nick = 'nickname'
          irc.channel = '#channel'
          irc.port = 6697
          irc.ssl = 1
          irc.server = 'irc.example.org'
        end

        expect( notifier.nick    ).to eq 'nickname'
        expect( notifier.channel ).to eq '#channel'
        expect( notifier.port    ).to be(6697)
        expect( notifier.ssl     ).to be(1)
        expect( notifier.server  ).to eq 'irc.example.org'
      end
    end # describe '#initialize'

    describe '#notify!' do
      let(:notifier) {
        Notifier::IRC.new(model) do |irc|
          irc.nick = "nickname"
          irc.channel = "#channel"
          irc.port = 6697
        end
      }

      it 'calls Cinch::Bot.start' do
        Cinch::Logger::FormattedLogger.any_instance.stubs(:debug)
        Cinch::Bot.any_instance.expects(:start).once
        notifier.send(:notify!, :success)
      end
    end # describe '#notify!'

  end
end
