# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::Dropbox do

  let(:db) do
    Backup::Storage::Dropbox.new do |db|
      db.api_key     = 'my_api_key'
      db.api_secret  = 'my_secret'
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
    STDIN.stubs(:gets)
  end

  it 'should have defined the configuration properly' do
    db.api_key.should     == 'my_api_key'
    db.api_secret.should  == 'my_secret'
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
    before do
      db.stubs(:gets)
    end

    context "when the session cache has not yet been written" do
      it do
        session = mock("Dropbox::Session")
        Dropbox::Session.expects(:new).with('my_api_key', 'my_secret').returns(session)
        session.expects(:mode=).with(:dropbox)
        session.expects(:authorize)
        db.expects(:cache_exists?).returns(false)
        db.expects(:write_cache!).with(session)

        template = Backup::Template.new(db.send(:binding))
        Backup::Template.expects(:new).returns(template)

        template.expects(:render).times(3)
        db.send(:connection)
      end
    end

    context "when the session cache has already been written" do
      it "should load the session from cache, instead of creating a new one" do
        db.expects(:cache_exists?).returns(true)
        File.expects(:read).with("#{ENV['HOME']}/Backup/.cache/my_api_keymy_secret").returns("foo")
        session = mock("Dropbox::Session")
        session.expects(:authorized?).returns(true)
        Dropbox::Session.expects(:deserialize).with("foo").returns(session)

        db.expects(:create_write_and_return_new_session!).never
        db.send(:connection)
      end

      it "should load it from cache, but if it's invalid/corrupt, the create a session anyway" do
        db.expects(:cache_exists?).returns(true)
        File.expects(:read).with("#{ENV['HOME']}/Backup/.cache/my_api_keymy_secret").returns("foo")
        session = mock("Dropbox::Session")
        session.expects(:authorized?).returns(false)
        Dropbox::Session.expects(:deserialize).with("foo").returns(session)

        db.expects(:create_write_and_return_new_session!)
        db.send(:connection)
      end
    end
  end

  describe '#transfer!' do
    before do
      connection.stubs(:upload)
      connection.stubs(:delete)
    end

    it do
      Backup::Logger.expects(:message).with(
        "Backup::Storage::Dropbox started transferring " +
        "'#{ Backup::TIME }.#{ Backup::TRIGGER }.tar'."
      )
      db.send(:transfer!)
    end

    it do
      connection.expects(:upload).with(
        File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar"),
        File.join('backups', Backup::TRIGGER, Backup::TIME),
        :as      => "#{ Backup::TRIGGER }.tar",
        :timeout => db.timeout
      )

      db.send(:transfer!)
    end
  end

  describe '#remove!' do
    it do
      connection.expects(:delete).with(
        File.join('backups', Backup::TRIGGER, Backup::TIME)
      )

      db.send(:remove!)
    end
  end

end
