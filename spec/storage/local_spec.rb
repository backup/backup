# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Storage::Local do

  let(:local) do
    Backup::Storage::Local.new do |local|
      local.path = '~/backups/'
      local.keep = 20
    end
  end

  before do
    Backup::Configuration::Storage::Local.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    local.path.should == "#{ENV['HOME']}/backups/"
    local.keep.should == 20
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::Local.defaults do |local|
      local.path = '~/backups'
    end

    local = Backup::Storage::Local.new do |local|
      local.path = '~/my-backups'
    end

    local.path.should == "#{ENV['HOME']}/my-backups"
  end

  it 'should have its own defaults' do
    local = Backup::Storage::Local.new
    local.path.should == "#{ENV['HOME']}/backups"
  end

  describe '#transfer!' do
    before do
      local.stubs(:create_local_directories!)
    end

    it 'should transfer the provided file to the path' do
      Backup::Model.new('blah', 'blah') {}

      local.expects(:create_local_directories!)

      FileUtils.expects(:cp).with(
        File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar"),
        File.join("#{ENV['HOME']}/backups/myapp", "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      )

      local.send(:transfer!)
    end
  end

  describe '#remove!' do
    it 'should remove the file from the remote server path' do
      FileUtils.expects(:rm).with("#{ENV['HOME']}/backups/myapp/#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      local.send(:remove!)
    end
  end

  describe '#create_remote_directories!' do
    it 'should properly create remote directories one by one' do
      local.path = "#{ENV['HOME']}/backups/some_other_folder/another_folder"
      FileUtils.expects(:mkdir_p).with("#{ENV['HOME']}/backups/some_other_folder/another_folder/myapp")
      local.send(:create_local_directories!)
    end
  end

  describe '#perform' do
    it 'should invoke transfer! and cycle!' do
      local.expects(:transfer!)
      local.expects(:cycle!)
      local.perform!
    end
  end

end
