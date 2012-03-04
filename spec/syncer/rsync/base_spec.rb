# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe 'Backup::Syncer::RSync::Base' do
  let(:base)    { Backup::Syncer::RSync::Base }
  let(:syncer)  { base.new }

  it 'should be a subclass of Syncer::Base' do
    base.superclass.should == Backup::Syncer::Base
  end

  describe '#initialize' do

    it 'should inherit default values from the superclass' do
      syncer.path.should    == 'backups'
      syncer.mirror.should  == false
    end

    it 'should set default values' do
      syncer.additional_options.should == []
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Syncer::RSync::Base.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Syncer::RSync::Base.defaults do |rsync|
          rsync.additional_options = 'some_additional_options'
        end
        syncer = Backup::Syncer::RSync::Base.new
        syncer.additional_options.should == 'some_additional_options'
      end
    end

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
