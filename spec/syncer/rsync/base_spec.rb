# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe 'Backup::Syncer::RSync::Base' do
  let(:syncer) { Backup::Syncer::RSync::Base.new }

  it 'should be a subclass of Syncer::Base' do
    Backup::Syncer::RSync::Base.
      superclass.should == Backup::Syncer::Base
  end

  describe '#initialize' do
    after { Backup::Syncer::RSync::Base.clear_defaults! }

    it 'should load pre-configured defaults through Syncer::Base' do
      Backup::Syncer::RSync::Base.any_instance.expects(:load_defaults!)
      syncer
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use default values' do
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.directories.should == []
        syncer.additional_options.should == []
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Syncer::RSync::Base.defaults do |rsync|
          rsync.path    = 'some_path'
          rsync.mirror  = 'some_mirror'
          rsync.additional_options = 'some_additional_options'
        end
      end

      it 'should use pre-configured defaults' do
        syncer.path.should    == 'some_path'
        syncer.mirror.should  == 'some_mirror'
        syncer.directories.should == []
        syncer.additional_options.should == 'some_additional_options'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#directory_options' do
    before do
      syncer.instance_variable_set(
        :@directories,  ['/some/directory', '/another/directory']
      )
    end

    it 'should return the directories for use in the command line' do
      syncer.send(:directories_option).should ==
          "'/some/directory' '/another/directory'"
    end

    context 'when @directories have relative paths' do
    before do
      syncer.instance_variable_set(
        :@directories,  ['/some/directory', '/another/directory',
                        'relative/path', '~/home/path']
      )
    end
      it 'should expand relative paths' do
        syncer.send(:directories_option).should ==
            "'/some/directory' '/another/directory' " +
            "'#{ File.expand_path('relative/path') }' " +
            "'#{ File.expand_path('~/home/path') }'"
      end
    end
  end

  describe '#mirror_option' do
    context 'when @mirror is true' do
      before { syncer.mirror = true }
      it 'should return the command line flag for mirroring' do
        syncer.send(:mirror_option).should == '--delete'
      end
    end

    context 'when @mirror is false' do
      before { syncer.mirror = false }
      it 'should return nil' do
        syncer.send(:mirror_option).should be_nil
      end
    end
  end

  describe '#archive_option' do
    it 'should return the command line flag for archiving' do
      syncer.send(:archive_option).should == '--archive'
    end
  end

end
