# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Syncer::Base do
  let(:base)    { Backup::Syncer::Base }
  let(:syncer)  { base.new }

  it 'should include CLI::Helpers' do
    base.included_modules.should include(Backup::CLI::Helpers)
  end

  it 'should include Configuration::Helpers' do
    base.included_modules.should include(Backup::Configuration::Helpers)
  end

  describe '#initialize' do

    it 'should use default values' do
      syncer.path.should               == 'backups'
      syncer.mirror.should             == false
      syncer.directories.should        == []
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Syncer::Base.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Syncer::Base.defaults do |base|
          base.path               = 'some_path'
          base.mirror             = 'some_mirror'
          #base.directories        = 'cannot_have_a_default_value'
        end
        syncer = Backup::Syncer::Base.new
        syncer.path.should               == 'some_path'
        syncer.mirror.should             == 'some_mirror'
        syncer.directories.should        == []
      end
    end

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
