# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Storage::Dropbox do

  let(:db) do
    Backup::Storage::Dropbox.new do |db|
      db.serialized_session = '/file/path/here'
      db.keep        = 20
      db.timeout     = 500
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
    db.serialized_session.should     == '/file/path/here'
    db.path.should        == 'backups'
    db.keep.should        == 20
    db.timeout.should     == 500
  end

  it 'should overwrite the default timeout' do
    db = Backup::Storage::Dropbox.new do |db|
      db.timeout = 500
    end

    db.timeout.should == 500
  end

  it 'should provide a default timeout' do
    db = Backup::Storage::Dropbox.new

    db.timeout.should == 300
  end

  it 'should overwrite the default path' do
    db = Backup::Storage::Dropbox.new do |db|
      db.path = 'my/backups'
    end

    db.path.should == 'my/backups'
  end

  describe '#connection' do
    it do
      file = mock('File')
      File.expects(:read).once.with('/file/path/here').returns(file)

      session = mock("Dropbox::Session")
      Dropbox::Session.expects(:deserialize).with(file).returns(session)

      session.expects(:mode=).with(:dropbox)

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
        :timeout => db.timeout
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
