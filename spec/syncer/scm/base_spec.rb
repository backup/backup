# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Syncer::SCM::Base do
  let(:syncer) { Backup::Syncer::SCM::Base.new }

  describe '#initialize' do

    it 'should use default values' do
      syncer.path.should                == 'backups'
      syncer.repositories.should        == []
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Syncer::SCM::Base.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Syncer::SCM::Base.defaults do |default|
          default.path               = 'some_path'
          #default.directories       = 'cannot_have_a_default_value'
        end
        syncer = Backup::Syncer::SCM::Base.new
        syncer.path.should               == 'some_path'
        syncer.repositories.should       == []
      end
    end

  end # describe '#initialize'

  describe '#repositories' do
    before do
      syncer.repositories = ['/some/repo.git', '/a/svn/repo']
    end

    context 'when no block is given' do
      it 'should return repositories' do
        syncer.repositories.should ==
            ['/some/repo.git', '/a/svn/repo']
      end
    end

    context 'when a block is given' do
      it 'should evalute the block, allowing #add to add directories' do
        syncer.repositories do
          add '/a/new/repo.git'
          add '/another/new/repo.git'
        end
        syncer.repositories.should == [
          '/some/repo.git',
          '/a/svn/repo',
          '/a/new/repo.git',
          '/another/new/repo.git'
        ]
      end
    end
  end # describe '#repositories'

  describe '#add' do
    before do
      syncer.repositories = ['/some/repo.git', '/another/repo.git']
    end

    it 'should add the given path to repositories' do
      syncer.add '/yet/another/repo.git'
      syncer.repositories.should ==
          ['/some/repo.git', '/another/repo.git', '/yet/another/repo.git']
    end
  end

  context 'when handling fully-qualified repositories' do

    before do
      syncer.protocol = 'http'
      syncer.username = 'jimmy'
      syncer.password = 'secret'
      syncer.ip       = 'example.com'
      syncer.port     = '80'
    end

    describe '#authority' do

      it "gets calculated using protocol, host, port and path" do
        syncer.authority.should == "http://jimmy:secret@example.com:80"
      end

      it "ignores missing port successfully" do
        syncer.port = nil
        syncer.authority.should == "http://jimmy:secret@example.com"
      end

      it "ignores missing user successfully" do
        syncer.username = nil
        syncer.authority.should == "http://example.com:80"
      end

      it "ignores missing password successfully" do
        syncer.password = nil
        syncer.authority.should == "http://jimmy@example.com:80"
      end
    end

    describe "#repository_url" do
      it "given a repository, it returns the local path where it will be stored" do
        syncer.repository_url('/my/repo.git').should == "http://jimmy:secret@example.com:80/my/repo.git"
      end
    end

    describe "#repository_urls" do
      it "returns the repositories prefixed with the authority" do
        syncer.repositories do
          add '/my/repo.git'
          add '/my/other/repo.git'
        end
        syncer.repository_urls.should == [
          "http://jimmy:secret@example.com:80/my/repo.git",
          "http://jimmy:secret@example.com:80/my/other/repo.git"
        ]
      end
    end
  end

  describe "#repository_local_path" do
    it "returns the path of a given repository" do
      syncer.repository_local_path("/my/repo.git").should == "backups/my/repo.git"
    end
  end

  describe "#repository_absolute_local_path" do
    it "returns the absolute path of a given repository" do
      result = "/home/jimmy/backups/my/repo"
      File.expects(:absolute_path).with("backups/my/repo").returns(result)
      syncer.repository_absolute_local_path("/my/repo").should == result
    end
  end

  describe "#repository_local_container_path" do
    it "returns the path of the directory that will contain the repo locally" do
      syncer.repository_local_container_path("/my/deep/repo.git").should == "backups/my/deep"
    end
  end

  describe "#create_repository_local_container!" do
    it "creates the container if needed" do
      FileUtils.stubs(:mkdir_p)
      FileUtils.expects(:mkdir_p).with("backups/my/deep")
      syncer.create_repository_local_container!("/my/deep/repo.git")
    end
  end

  describe "#perform!" do
    it "invokes update_repository once per each repository" do
      syncer.stubs(:backup_repository!)

      syncer.repositories do
        add '/my/repo.git'
        add '/my/other/repo.git'
      end

      Backup::Logger.expects(:message).with("Backup::Syncer::SCM::Base started syncing 'backups'.")
      syncer.expects(:backup_repository!).with('/my/repo.git')
      syncer.expects(:backup_repository!).with('/my/other/repo.git')

      syncer.perform!
    end
  end

  describe "#backup_repository!" do
    it "throws an error when invoked" do
      lambda { syncer.backup_repository('my/repo.git') }.should raise_error
    end
  end

end
