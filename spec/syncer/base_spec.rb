# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Syncer::Base do
  let(:syncer)    { Backup::Syncer::Base.new }

  it 'should include Utilities::Helpers' do
    Backup::Syncer::Base.
      include?(Backup::Utilities::Helpers).should be_true
  end

  it 'should include Configuration::Helpers' do
    Backup::Syncer::Base.
      include?(Backup::Configuration::Helpers).should be_true
  end

  describe '#initialize' do
    after { Backup::Syncer::Base.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Syncer::Base.any_instance.expects(:load_defaults!)
      syncer
    end

    it 'should establish a new array for @directories' do
      syncer.directories.should == []
    end

    context 'when no pre-configured defaults have been set' do
      it 'should set default values' do
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Syncer::Base.defaults do |s|
          s.path   = 'some_path'
          s.mirror = 'some_mirror'
        end
      end

      it 'should use pre-configured defaults' do
        syncer.path.should    == 'some_path'
        syncer.mirror.should  == 'some_mirror'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#directories' do
    before do
      syncer.instance_variable_set(
        :@directories,  ['/some/directory', '/another/directory']
      )
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
      syncer.instance_variable_set(
        :@directories,  ['/some/directory', '/another/directory']
      )
    end

    it 'should add the given path to @directories' do
      syncer.add '/my/path'
      syncer.directories.should ==
          ['/some/directory', '/another/directory', '/my/path']
    end

    # Note: Each Syncer should handle this as needed.
    # For example, expanding these here would break RSync::Pull
    it 'should not expand the given paths' do
      syncer.add 'relative/path'
      syncer.directories.should ==
          ['/some/directory', '/another/directory', 'relative/path']
    end
  end

  describe '#syncer_name' do
    it 'should return the class name with the Backup:: namespace removed' do
      syncer.send(:syncer_name).should == 'Syncer::Base'
    end
  end
end
