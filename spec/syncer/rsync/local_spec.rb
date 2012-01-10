# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Syncer::RSync::Local do
  let(:syncer) do
    Backup::Syncer::RSync::Local.new do |rsync|
      rsync.path = "~/my_backups"

      rsync.directories do |directory|
        directory.add "/some/directory"
        directory.add "~/home/directory"
      end

      rsync.mirror             = true
      rsync.additional_options = ['--opt-a', '--opt-b']
    end
  end

  it 'should be a subclass of RSync::Base' do
    Backup::Syncer::RSync::Local.superclass.should == Backup::Syncer::RSync::Base
  end

  describe '#initialize' do
    it 'should have defined the configuration properly' do
      syncer.path.should               == '~/my_backups'
      syncer.directories.should        == ["/some/directory", "~/home/directory"]
      syncer.mirror.should             == true
      syncer.additional_options.should == ['--opt-a', '--opt-b']
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Syncer::RSync::Local.clear_defaults! }

      it 'should override the configured defaults' do
        Backup::Configuration::Syncer::RSync::Local.defaults do |rsync|
          rsync.path               = 'old_path'
          #rsync.directories        = 'cannot_have_a_default_value'
          rsync.mirror             = 'old_mirror'
          rsync.additional_options = 'old_additional_options'
        end
        syncer = Backup::Syncer::RSync::Local.new do |rsync|
          rsync.path               = 'new_path'
          rsync.directories        = 'new_directories'
          rsync.mirror             = 'new_mirror'
          rsync.additional_options = 'new_additional_options'
        end

        syncer.path.should               == 'new_path'
        syncer.directories.should        == 'new_directories'
        syncer.mirror.should             == 'new_mirror'
        syncer.additional_options.should == 'new_additional_options'
      end
    end # context 'when setting configuration defaults'
  end # describe '#initialize'

  describe '#perform!' do
    let(:s) { sequence '' }

    before do
      syncer.expects(:utility).with(:rsync).returns('rsync')
      syncer.expects(:options).returns('options_output')
    end

    it 'should sync two directories' do
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Syncer::RSync::Local started syncing the following directories:\n" +
        "  /some/directory\n" +
        "  ~/home/directory"
      )
      syncer.expects(:run).in_sequence(s).with(
        "rsync options_output '/some/directory' " +
        "'#{ File.expand_path('~/home/directory') }' " +
        "'#{ File.expand_path('~/my_backups') }'"
      ).returns('messages from stdout')
      Backup::Logger.expects(:silent).in_sequence(s).with('messages from stdout')

      syncer.perform!
    end
  end # describe '#perform!'

  describe '#dest_path' do
    it 'should return @path expanded' do
      syncer.send(:dest_path).should == File.expand_path('~/my_backups')
    end

    it 'should set @dest_path' do
      syncer.send(:dest_path)
      syncer.instance_variable_get(:@dest_path).should ==
          File.expand_path('~/my_backups')
    end

    it 'should return @dest_path if already set' do
      syncer.instance_variable_set(:@dest_path, 'foo')
      syncer.send(:dest_path).should == 'foo'
    end
  end

  describe '#options' do
    context 'when @mirror is true' do
      it 'should return the options with mirroring enabled' do
        syncer.send(:options).should == '--archive --delete --opt-a --opt-b'
      end
    end

    context 'when @mirror is false' do
      before { syncer.mirror = false }
      it 'should return the options without mirroring enabled' do
        syncer.send(:options).should == '--archive --opt-a --opt-b'
      end
    end

    context 'when no additional options are given' do
      before { syncer.additional_options = [] }
      it 'should return the options without additional options' do
        syncer.send(:options).should == '--archive --delete'
      end
    end
  end

end
