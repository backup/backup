# encoding: utf-8
require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Syncer::SCM::Git do

  let(:git) do
    Backup::Syncer::SCM::Git.new do |git|
      git.ip        = 'example.com'
      git.repositories do
        add '/a/repo.git'
        add '/another/repo.git'
      end
    end
  end

  describe '#initialize' do
    it 'should use default values' do
      git.protocol                  == 'git'
      git.path.should               == 'backups'
      git.repositories.should       == ['/a/repo.git', '/another/repo.git']
    end
  end



  it 'should be a subclass of SCM::Base' do
    Backup::Syncer::SCM::Git.superclass.should == Backup::Syncer::SCM::Base
  end

  describe '#local_repository_exists?' do
    let(:command) { "cd backups/my_repo && git rev-parse --git-dir > /dev/null 2>&1" }
    it "returns false when not in a working copy" do
      git.expects(:run).with(command).raises(Backup::Errors::CLI::SystemCallError)
      git.local_repository_exists?("my_repo").should be_false
    end

    it "returns true when inside a working copy" do
      git.expects(:run).with(command)
      git.local_repository_exists?("my_repo").should be_true
    end
  end

  describe '#clone_repository!' do
    it 'initializes an empty repository' do
      Backup::Logger.expects(:message).with("Cloning repository in 'backups/my/repo.git'.")
      git.expects(:create_repository_local_container!).with('/my/repo.git')
      git.expects(:run).with("cd backups/my && git clone --bare git://example.com/my/repo.git")

      git.clone_repository!('/my/repo.git')
    end
  end

  describe '#update_repository!' do
    it 'invokes git fetch' do
      Backup::Logger.expects(:message).with("Updating repository in 'backups/my/repo.git'.")
      git.expects(:run).with("cd backups/my/repo.git && git fetch --all")

      git.update_repository!('/my/repo.git')
    end
  end

  describe '#backup_repository!' do
    context 'when the local repository exists' do
      it 'invokes update_repository!' do
        git.expects(:local_repository_exists?).with('/my/repo.git').returns(true)
        git.expects(:update_repository!).with('/my/repo.git')

        git.backup_repository!('/my/repo.git')
      end
    end
    context 'when the local repository does not exist' do
      it 'invokes clone_repository!' do
        git.expects(:local_repository_exists?).with('/my/repo.git').returns(false)
        git.expects(:clone_repository!).with('/my/repo.git')

        git.backup_repository!('/my/repo.git')
      end
    end
  end
end
