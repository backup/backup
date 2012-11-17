# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Notifier::Mail',
    :if => Backup::SpecLive::CONFIG['notifier']['mail']['specs_enabled'] do
  describe 'Notifier::Mail :smtp' do
    let(:trigger) { 'notifier_mail' }

    it 'should send a success email' do
      model = h_set_trigger(trigger)
      model.perform!

      Backup::Logger.has_warnings?.should be_false
      Backup::Logger.messages.any? {|msg| msg =~ /\[error\]/ }.should be_false
    end

    it 'should send a warning email' do
      model = h_set_trigger(trigger)
      Backup::Logger.warn 'You have been warned!'
      model.perform!

      Backup::Logger.has_warnings?.should be_true
      Backup::Logger.messages.any? {|msg| msg =~ /\[error\]/ }.should be_false
    end

    it 'should send a failure email for non-fatal errors' do
      model = h_set_trigger(trigger)
      model.stubs(:databases).raises('A successful failure?')
      model.perform!

      Backup::Logger.has_warnings?.should be_false
      Backup::Logger.messages.any? {|msg|
        msg =~ /\[error\]\s+A successful failure/
      }.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /Backup will now attempt to continue/
      }.should be_true
    end

    it 'should send a failure email for fatal errors' do
      model = h_set_trigger(trigger)
      model.stubs(:databases).raises(NoMemoryError, 'with increasing frequency...')
      expect do
        model.perform!
      end.to raise_error(SystemExit)

      Backup::Logger.has_warnings?.should be_false
      Backup::Logger.messages.any? {|msg|
        msg =~ /with increasing frequency/
      }.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /Backup will now exit/
      }.should be_true
    end
  end # describe 'Notifier::Mail :smtp'

  describe 'Notifier::Mail :file' do
    let(:trigger) { 'notifier_mail_file' }
    let(:test_email) { File.join(Backup::SpecLive::TMP_PATH, 'test@backup') }

    it 'should send a success email' do
      model = h_set_trigger(trigger)
      model.perform!

      Backup::Logger.has_warnings?.should be_false
      Backup::Logger.messages.any? {|msg| msg =~ /\[error\]/ }.should be_false

      File.exist?(test_email).should be_true
      File.read(test_email).should match(/without any errors/)
    end

    it 'should send a warning email' do
      model = h_set_trigger(trigger)
      Backup::Logger.warn 'You have been warned!'
      model.perform!

      Backup::Logger.has_warnings?.should be_true
      Backup::Logger.messages.any? {|msg| msg =~ /\[error\]/ }.should be_false

      File.exist?(test_email).should be_true
      File.read(test_email).should match(/You have been warned/)
    end

    it 'should send a failure email for non-fatal errors' do
      model = h_set_trigger(trigger)
      model.stubs(:databases).raises('A successful failure?')
      model.perform!

      Backup::Logger.has_warnings?.should be_false
      Backup::Logger.messages.any? {|msg|
        msg =~ /\[error\]\s+A successful failure/
      }.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /Backup will now attempt to continue/
      }.should be_true

      File.exist?(test_email).should be_true
      File.read(test_email).should match(/successful failure/)
    end

    it 'should send a failure email for fatal errors' do
      model = h_set_trigger(trigger)
      model.stubs(:databases).raises(NoMemoryError, 'with increasing frequency...')
      expect do
        model.perform!
      end.to raise_error(SystemExit)

      Backup::Logger.has_warnings?.should be_false
      Backup::Logger.messages.any? {|msg|
        msg =~ /with increasing frequency/
      }.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /Backup will now exit/
      }.should be_true

      File.exist?(test_email).should be_true
      File.read(test_email).should match(/with increasing frequency/)
    end
  end # describe 'Notifier::Mail :file'
end
