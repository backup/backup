# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'

describe Backup::Archive do

  let(:archive) do
    Backup::Archive.new(:dummy_archive) do |a|
      a.add '/home/rspecuser/somefile'
      a.add '/home/rspecuser/logs/'
      a.add '/home/rspecuser/dotfiles/'
    end
  end

  it 'should have no paths' do
    archive = Backup::Archive.new(:dummy_archive) { |a| }
    archive.paths.count.should == 0
  end

  it 'should have 3 paths' do
    archive.paths.count.should == 3
  end

  it do
    archive.name.should == :dummy_archive
  end

  describe '#paths_to_package' do
    it 'should return a tar -c friendly string' do
      archive.send(:paths_to_package).should ==
      "'/home/rspecuser/somefile' '/home/rspecuser/logs/' '/home/rspecuser/dotfiles/'"
    end
  end

  describe '#perform!' do
    before do
      [:mkdir, :run, :utility].each { |method| archive.stubs(method) }
      Backup::Logger.stubs(:message)
    end

    it 'should tar all the specified paths' do
      archive.expects(:mkdir).with(File.join(Backup::TMP_PATH, Backup::TRIGGER, 'archive'))
      archive.expects(:run).with("tar -c '/home/rspecuser/somefile' '/home/rspecuser/logs/' '/home/rspecuser/dotfiles/' 1> '#{File.join(Backup::TMP_PATH, Backup::TRIGGER, 'archive', "#{:dummy_archive}.tar")}' 2> /dev/null")
      archive.expects(:utility).with(:tar).returns(:tar)
      archive.perform!
    end

    it 'should log the status' do
      Backup::Logger.expects(:message).with("Backup::Archive started packaging and archiving \"/home/rspecuser/somefile\", \"/home/rspecuser/logs/\", \"/home/rspecuser/dotfiles/\".")
      archive.perform!
    end
  end
end
