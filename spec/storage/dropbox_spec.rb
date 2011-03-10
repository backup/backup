# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Storage::Dropbox do

  let(:db) do
    Backup::Storage::Dropbox.new do |db|
      db.email       = 'my@email.com'
      db.password    = 'my_password'
      db.api_key     = 'my_api_key'
      db.api_secret  = 'my_secret'
      db.keep        = 20
    end
  end

  let(:connection) do
    c = mock("Dropbox::Session")
    db.stubs(:connection).returns(c); c
  end

  before do
    Backup::Configuration::Storage::Dropbox.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    db.email.should       == 'my@email.com'
    db.password.should    == 'my_password'
    db.api_key.should     == 'my_api_key'
    db.api_secret.should  == 'my_secret'
    db.path.should        == 'backups'
    db.keep.should        == 20
  end

  it 'should overwrite the default path' do
    db = Backup::Storage::Dropbox.new do |db|
      db.path = 'my/backups'
    end

    db.path.should == 'my/backups'
  end

  describe '#connection' do
    it do
      session = mock("Dropbox::Session")
      Dropbox::Session.expects(:new).with('my_api_key', 'my_secret').returns(session)
      session.expects(:mode=).with(:dropbox)
      session.expects(:authorizing_user=).with('my@email.com')
      session.expects(:authorizing_password=).with('my_password')
      session.expects(:authorize!)

      db.send(:connection)
    end
  end

  describe '#transfer!' do
    before do
      Backup::Logger.stubs(:message)
      connection.stubs(:upload)
      connection.stubs(:delete)
    end

    it do
      Backup::Logger.expects(:message).with("Backup::Storage::Dropbox started transferring \"#{ Backup::TIME }.#{ Backup::TRIGGER }.tar\".")
      db.send(:transfer!)
    end

    it do
      connection.expects(:upload).with(
        File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar"),
        File.join('backups', Backup::TRIGGER),
        :timeout => 300
      )

      db.send(:transfer!)
    end
  end

  describe '#remove!' do
    it do
      connection.expects(:delete).with(
        File.join('backups', Backup::TRIGGER, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      )

      db.send(:remove!)
    end
  end

end
