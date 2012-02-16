# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Syncer::SCM::SVN do

  let(:svn) do
    Backup::Syncer::SCM::SVN.new do |svn|
      svn.ip        = 'example.com'
      svn.repositories do
        add '/a/repo/trunk'
        add '/another/repo/trunk'
      end
    end
  end

  describe '#initialize' do
    it 'should use default values' do
      svn.protocol                  == 'http'
      svn.path.should               == 'backups'
      svn.repositories.should       == ['/a/repo/trunk', '/another/repo/trunk']
    end
  end

  it 'should be a subclass of SCM::Base' do
    Backup::Syncer::SCM::SVN.superclass.should == Backup::Syncer::SCM::Base
  end


  describe '#local_repository_exists?' do
    it "returns false when not in a working copy" do
      svn.expects(:run).with('svnadmin verify backups/my_repo').raises(Backup::Errors::CLI::SystemCallError)
      svn.local_repository_exists?("my_repo").should be_false
    end
    it "returns true when inside a working copy" do
      svn.expects(:run).with('svnadmin verify backups/my_repo')
      svn.local_repository_exists?("my_repo").should be_true
    end
  end

  describe '#backup_repository!' do
    context 'when the local repository exists' do
      it 'invokes update_repository! only' do
        svn.expects(:local_repository_exists?).with('/my/repo').returns(true)
        svn.expects(:update_repository!).with('/my/repo')

        svn.backup_repository!('/my/repo')
      end
    end
    context 'when the local repository does not exist' do
      it 'invokes initialize_repository! and then update_repository!' do

        svn.expects(:local_repository_exists?).with('/my/repo').returns(false)
        svn.expects(:initialize_repository!).with('/my/repo')
        svn.expects(:update_repository!).with('/my/repo')

        svn.backup_repository!('/my/repo')
      end
    end
  end

  describe '#initialize_repository!' do
    it 'initializes an empty repository' do
      absolute_path = '/home/jimmy/backups/my/repo'

      Backup::Logger.expects(:message).with("Initializing empty svn repository in 'backups/my/repo'.")

      svn.expects(:repository_absolute_local_path).with('/my/repo').returns(absolute_path)

      svn.expects(:create_repository_local_container!).with('/my/repo')

      svn.expects(:run).with("svnadmin create 'backups/my/repo'")
      svn.expects(:run).with("echo '#!/bin/sh' > 'backups/my/repo/hooks/pre-revprop-change'")
      svn.expects(:run).with("chmod +x 'backups/my/repo/hooks/pre-revprop-change'")
      svn.expects(:run).with("svnsync init file://#{absolute_path} http://example.com/my/repo")

      svn.initialize_repository!('/my/repo')
    end
  end

  describe '#update_repository!' do
    it 'updates an existing repository' do
      absolute_path = '/home/jimmy/backups/my/repo'

      Backup::Logger.expects(:message).with("Updating svn repository in 'backups/my/repo'.")

      svn.expects(:repository_absolute_local_path).with('/my/repo').returns(absolute_path)
      svn.expects(:run).with("svnsync sync file://#{absolute_path} --non-interactive")

      svn.update_repository!('/my/repo')
    end
  end

end
