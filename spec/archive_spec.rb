# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'

describe Backup::Archive do

  let(:archive) do
    Backup::Archive.new(:dummy_archive) do |a|
      a.add '/home/rspecuser/somefile'
      a.add '/home/rspecuser/logs'
      a.add '/home/rspecuser/dotfiles'
      a.exclude '/home/rspecuser/badfile'
      a.exclude '/home/rspecuser/wrongdir'
    end
  end

  it 'should have no paths' do
    archive = Backup::Archive.new(:dummy_archive) { |a| }
    archive.paths.count.should == 0
  end

  it 'should have no excludes' do
    archive = Backup::Archive.new(:dummy_archive) { |a| }
    archive.excludes.count.should == 0
  end

  it 'should have 3 paths' do
    archive.paths.count.should == 3
  end

  it 'should have 2 excludes' do
    archive.excludes.count.should == 2
  end

  it do
    archive.name.should == :dummy_archive
  end

  describe '#paths_to_package' do
    it 'should return a tar -c friendly string' do
      archive.send(:paths_to_package).should ==
      "'/home/rspecuser/somefile' '/home/rspecuser/logs' '/home/rspecuser/dotfiles'"
    end
  end

  describe '#paths_to_exclude' do
    it 'should be empty' do
      archive = Backup::Archive.new(:dummy_archive) { |a| }
      archive.send(:paths_to_exclude).should be_nil
    end

    it 'should return a tar -c friendly string' do
      archive.send(:paths_to_exclude).should ==
      "--exclude='/home/rspecuser/badfile' --exclude='/home/rspecuser/wrongdir'"
    end
  end

  describe '#perform!' do
    before do
      [:mkdir, :run, :utility].each { |method| archive.stubs(method) }
    end

    context 'when both paths were added and paths that should be excluded were added' do
      it 'should render both the syntax for the paths that be included as well as excluded' do
        archive.expects(:mkdir).with(File.join(Backup::TMP_PATH, Backup::TRIGGER, 'archive'))
        archive.expects(:run).with(
          "tar -c -f '#{File.join(Backup::TMP_PATH, Backup::TRIGGER, 'archive', "#{:dummy_archive}.tar")}' --exclude='/home/rspecuser/badfile' --exclude='/home/rspecuser/wrongdir' '/home/rspecuser/somefile' '/home/rspecuser/logs' '/home/rspecuser/dotfiles'",
          :ignore_exit_codes => [1]
        )
        archive.expects(:utility).with(:tar).returns(:tar)
        archive.perform!
      end
    end

    context 'when there are paths to add, and no exclude patterns were defined' do
      it 'should only render syntax for the defined paths' do
        archive = Backup::Archive.new(:dummy_archive) do |a|
          a.add '/path/to/archive'
        end

        archive.stubs(:utility).returns(:tar)
        archive.expects(:run).with(
          "tar -c -f '#{File.join(Backup::TMP_PATH, Backup::TRIGGER, 'archive', "#{:dummy_archive}.tar")}'  '/path/to/archive'",
          :ignore_exit_codes => [1]
        )
        archive.perform!
      end
    end

    it 'should log the status' do
      Backup::Logger.expects(:message).with("Backup::Archive started packaging and archiving \"/home/rspecuser/somefile\", \"/home/rspecuser/logs\", \"/home/rspecuser/dotfiles\".")
      archive.perform!
    end
  end
end
