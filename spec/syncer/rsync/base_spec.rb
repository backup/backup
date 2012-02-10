# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Syncer::RSync::Base do
  let(:syncer) { Backup::Syncer::RSync::Base.new }

  describe '#initialize' do

    it 'should use default values' do
      syncer.path.should               == 'backups'
      syncer.directories.should        == []
      syncer.mirror.should             == false
      syncer.additional_options.should == []
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Syncer::RSync::Base.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Syncer::RSync::Base.defaults do |rsync|
          rsync.path               = 'some_path'
          #rsync.directories        = 'cannot_have_a_default_value'
          rsync.mirror             = 'some_mirror'
          rsync.additional_options = 'some_additional_options'
        end
        syncer = Backup::Syncer::RSync::Base.new
        syncer.path.should               == 'some_path'
        syncer.directories.should        == []
        syncer.mirror.should             == 'some_mirror'
        syncer.additional_options.should == 'some_additional_options'
      end
    end

  end # describe '#initialize'

  describe '#directories' do
    before do
      syncer.directories = ['/some/directory', '/another/directory']
    end

    context 'when no block is given' do
      it 'should return @directories' do
        syncer.directories.should ==
            ['/some/directory', '/another/directory']
      end
    end

    context 'when a block is given' do
      it 'should evalute the block, allowing #add to add directories' do
        syncer.directories do
          add '/new/path'
          add '/another/new/path'
        end
        syncer.directories.should == [
          '/some/directory',
          '/another/directory',
          '/new/path',
          '/another/new/path'
        ]
      end
    end
  end # describe '#directories'

  describe '#add' do
    before do
      syncer.directories = ['/some/directory', '/another/directory']
    end

    it 'should add the given path to @directories' do
      syncer.add '/my/path'
      syncer.directories.should ==
          ['/some/directory', '/another/directory', '/my/path']
    end
  end

  describe '#directory_options' do
    before do
      syncer.directories = ['/some/directory', '/another/directory']
    end

    it 'should return the directories for use in the command line' do
      syncer.send(:directories_option).should ==
          "'/some/directory' '/another/directory'"
    end

    it 'should expand relative paths' do
      syncer.directories += ['relative/path', '~/home/path']
      syncer.send(:directories_option).should ==
          "'/some/directory' '/another/directory' " +
          "'#{ File.expand_path('relative/path') }' " +
          "'#{ File.expand_path('~/home/path') }'"
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
