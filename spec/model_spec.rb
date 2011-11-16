# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'

describe Backup::Model do

  before do
    # stub out the creation of an archive, for this spec's purpose
    Backup::Archive.stubs(:new).returns(true)

    # create mockup classes for testing the behavior of Backup::Model
    class Backup::Database::TestDatabase
      def initialize(&block); end
    end
    class Backup::Storage::TestStorage
      def initialize(&block); end
    end
    class Backup::Compressor::TestGzip
      def initialize(&block); end
    end
    class Backup::Compressor::TestSevenZip
      def initialize(&block); end
    end
    class Backup::Encryptor::TestOpenSSL
      def initialize(&block); end
    end
    class Backup::Encryptor::TestGPG
      def initialize(&block); end
    end
    class Backup::Notifier::TestMail
      def initialize(&block); end
    end

  end

  let(:model) { Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') {} }

  it do
    Backup::Model.extension.should == 'tar'
  end

  it do
    Backup::Model.new('foo', 'bar') {}
    Backup::Model.extension.should == 'tar'
  end

  before do
    Backup::Model.extension = 'tar'
  end

  it do
    Backup::Model.new('blah', 'blah') {}
    Backup::Model.extension.should == 'tar'
  end

  it do
    Backup::Model.new('blah', 'blah') {}
    Backup::Model.file.should == "#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }"
  end

  it do
    Backup::Model.new('blah', 'blah') {}
    File.basename(Backup::Model.file).should == "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar"
  end

  it do
    Backup::Model.new('blah', 'blah') {}
    Backup::Model.tmp_path.should == File.join(Backup::TMP_PATH, Backup::TRIGGER)
  end

  it 'should create a new model with a trigger and label' do
    model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') {}
    model.trigger.should == 'mysql-s3'
    model.label.should == 'MySQL S3 Backup for MyApp'
  end

  it 'should have the time logged in the object' do
    model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') {}
    model.time.should == Backup::TIME
  end

  describe '#extension' do
    it 'should start out with just .tar before compression occurs' do
      Backup::Model.extension.should == 'tar'
    end
  end

  describe 'databases' do
    it 'should add the mysql adapter to the array of databases to invoke' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        database('TestDatabase')
      end

      model.databases.count.should == 1
    end

    it 'should add 2 mysql adapters to the array of adapters to invoke' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        database('TestDatabase')
        database('TestDatabase')
      end

      model.databases.count.should == 2
    end
  end

  describe 'storages' do
    it 'should add a storage to the array of storages to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        store_with('TestStorage')
      end

      model.storages.count.should == 1
    end

    it 'should add a storage to the array of storages to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        store_with('TestStorage')
        store_with('TestStorage')
      end

      model.storages.count.should == 2
    end
  end

  describe 'archives' do
    it 'should add an archive to the array of archives to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        archive('my_archive')
      end

      model.archives.count.should == 1
    end

    it 'should add a storage to the array of storages to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        archive('TestStorage')
        archive('TestStorage')
      end

      model.archives.count.should == 2
    end
  end

  describe '#compress_with' do
    it 'should add a compressor to the array of compressors to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        compress_with('TestGzip')
      end

      model.compressors.count.should == 1
    end

    it 'should add a compressor to the array of compressors to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        compress_with('TestGzip')
        compress_with('TestSevenZip')
      end

      model.compressors.count.should == 2
    end
  end

  describe '#encrypt_with' do
    it 'should add a encryptor to the array of encryptors to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        encrypt_with('TestOpenSSL')
      end

      model.encryptors.count.should == 1
    end

    it 'should add a encryptor to the array of encryptors to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        encrypt_with('TestOpenSSL')
        encrypt_with('TestGPG')
      end

      model.encryptors.count.should == 2
    end
  end

  describe '#notify_by' do
    it 'should add a notifier to the array of notifiers to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        notify_by('TestMail')
      end

      model.notifiers.count.should == 1
    end

    it 'should add a notifier to the array of notifiers to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        notify_by('TestMail')
        notify_by('TestMail')
      end

      model.notifiers.count.should == 2
    end
  end

  describe '#package!' do
    before do
      [:utility, :run].each { |method| model.stubs(method) }
    end

    it 'should package the folder' do
      model.expects(:utility).with(:tar).returns(:tar)
      model.expects(:run).with(%|tar -c -f '#{ File.join( Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar" ) }' -C '#{ Backup::TMP_PATH }' '#{ Backup::TRIGGER }'|)
      model.send(:package!)
    end

    it 'should log' do
      Backup::Logger.expects(:message).with("Backup started packaging everything to a single archive file.")
      model.send(:package!)
    end
  end

  describe '#clean!' do
    before do
      [:utility, :run, :rm].each { |method| model.stubs(method) }
    end

    it 'should remove the temporary files and folders that were created' do
      model.expects(:utility).with(:rm).returns(:rm)
      model.expects(:run).with "rm -rf '#{ File.join(Backup::TMP_PATH, Backup::TRIGGER) }' " +
                               "'#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }'"

      model.send(:clean!)
    end

    it 'should remove the temporary files and folders that were created' do
      model.expects(:utility).with(:rm).returns(:rm)
      Backup::Model.chunk_suffixes = ["aa", "ab", "ac"]
      model.expects(:run).with "rm -rf '#{ File.join(Backup::TMP_PATH, Backup::TRIGGER) }' " +
                               "'#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }' " +
                               "'#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar-aa") }' " +
                               "'#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar-ab") }' " +
                               "'#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar-ac") }'"
      model.send(:clean!)
    end

    it do
      Backup::Logger.expects(:message).with("Backup started cleaning up the temporary files.")
      model.send(:clean!)
    end
  end

  describe '#split_into_chunks_of' do
    it do
      model.should respond_to(:split_into_chunks_of)
    end

    it do
      model.split_into_chunks_of(500)
      model.chunk_size.should == 500
    end

    it do
      model.chunk_size.should == nil
    end
  end

end
