# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Syncer::RSync::Local do
  let(:syncer) do
    Backup::Syncer::RSync::Local.new do |rsync|
      rsync.path    = "~/my_backups"
      rsync.mirror  = true
      rsync.additional_options = ['--opt-a', '--opt-b']

      rsync.directories do |directory|
        directory.add "/some/directory"
        directory.add "~/home/directory"
      end
    end
  end

  it 'should be a subclass of Syncer::RSync::Base' do
    Backup::Syncer::RSync::Local.
      superclass.should == Backup::Syncer::RSync::Base
  end

  describe '#initialize' do
    after { Backup::Syncer::RSync::Local.clear_defaults! }

    it 'should load pre-configured defaults through Syncer::Base' do
      Backup::Syncer::RSync::Local.any_instance.expects(:load_defaults!)
      syncer
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        syncer.path.should               == '~/my_backups'
        syncer.mirror.should             == true
        syncer.directories.should        == ["/some/directory", "~/home/directory"]
        syncer.additional_options.should == ['--opt-a', '--opt-b']
      end

      it 'should use default values if none are given' do
        syncer = Backup::Syncer::RSync::Local.new

        # from Syncer::Base
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.directories.should == []

        # from Syncer::RSync::Base
        syncer.additional_options.should == []
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Syncer::RSync::Local.defaults do |rsync|
          rsync.path    = 'some_path'
          rsync.mirror  = 'some_mirror'
          rsync.additional_options = 'some_additional_options'
        end
      end

      it 'should use pre-configured defaults' do
        syncer = Backup::Syncer::RSync::Local.new

        syncer.path.should    == 'some_path'
        syncer.mirror.should  == 'some_mirror'
        syncer.directories.should == []
        syncer.additional_options.should == 'some_additional_options'
      end

      it 'should override pre-configured defaults' do
        syncer = Backup::Syncer::RSync::Local.new do |rsync|
          rsync.path    = 'new_path'
          rsync.mirror  = 'new_mirror'
          rsync.additional_options = 'new_additional_options'
        end

        syncer.path.should    == 'new_path'
        syncer.mirror.should  == 'new_mirror'
        syncer.directories.should == []
        syncer.additional_options.should == 'new_additional_options'
      end
    end # context 'when pre-configured defaults have been set'
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
      )

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
