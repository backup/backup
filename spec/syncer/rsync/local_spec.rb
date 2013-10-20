# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

module Backup
describe Syncer::RSync::Local do
  before do
    Syncer::RSync::Local.any_instance.
        stubs(:utility).with(:rsync).returns('rsync')
  end

  describe '#initialize' do
    after { Syncer::RSync::Local.clear_defaults! }

    it 'should use the values given' do
      syncer = Syncer::RSync::Local.new do |rsync|
        rsync.path    = '~/my_backups'
        rsync.mirror  = true
        rsync.additional_rsync_options = ['--opt-a', '--opt-b']

        rsync.directories do |directory|
          directory.add '/some/directory'
          directory.add '~/home/directory'
          directory.exclude '*~'
          directory.exclude 'tmp/'
        end
      end

      expect( syncer.path         ).to eq '~/my_backups'
      expect( syncer.mirror       ).to be(true)
      expect( syncer.directories  ).to eq ['/some/directory', '~/home/directory']
      expect( syncer.excludes     ).to eq ['*~', 'tmp/']
      expect( syncer.additional_rsync_options ).to eq ['--opt-a', '--opt-b']
    end

    it 'should use default values if none are given' do
      syncer = Syncer::RSync::Local.new

      expect( syncer.path         ).to eq '~/backups'
      expect( syncer.mirror       ).to be(false)
      expect( syncer.directories  ).to eq []
      expect( syncer.excludes     ).to eq []
      expect( syncer.additional_rsync_options ).to be_nil
    end

    context 'when pre-configured defaults have been set' do
      before do
        Syncer::RSync::Local.defaults do |rsync|
          rsync.path    = 'some_path'
          rsync.mirror  = 'some_mirror'
          rsync.additional_rsync_options = 'rsync_options'
        end
      end

      it 'should use pre-configured defaults' do
        syncer = Syncer::RSync::Local.new

        expect( syncer.path         ).to eq 'some_path'
        expect( syncer.mirror       ).to eq 'some_mirror'
        expect( syncer.directories  ).to eq []
        expect( syncer.excludes     ).to eq []
        expect( syncer.additional_rsync_options ).to eq 'rsync_options'
      end

      it 'should override pre-configured defaults' do
        syncer = Syncer::RSync::Local.new do |rsync|
          rsync.path    = 'new_path'
          rsync.mirror  = 'new_mirror'
          rsync.additional_rsync_options = 'new_rsync_options'
        end

        expect( syncer.path         ).to eq 'new_path'
        expect( syncer.mirror       ).to eq 'new_mirror'
        expect( syncer.directories  ).to eq []
        expect( syncer.excludes     ).to eq []
        expect( syncer.additional_rsync_options ).to eq 'new_rsync_options'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#perform!' do

    specify 'with mirror option and Array of additional_rsync_options' do
      syncer = Syncer::RSync::Local.new do |rsync|
        rsync.path    = '~/my_backups'
        rsync.mirror  = true
        rsync.additional_rsync_options = ['--opt-a', '--opt-b']

        rsync.directories do |directory|
          directory.add '/some/directory/'
          directory.add '~/home/directory'
        end
      end

      FileUtils.expects(:mkdir_p).with(File.expand_path('~/my_backups/'))

      syncer.expects(:run).with(
        "rsync --archive --delete --opt-a --opt-b " +
        "'/some/directory' '#{ File.expand_path('~/home/directory') }' " +
        "'#{ File.expand_path('~/my_backups') }'"
      )

      syncer.perform!
    end

    specify 'without mirror option and String of additional_rsync_options' do
      syncer = Syncer::RSync::Local.new do |rsync|
        rsync.path    = '~/my_backups'
        rsync.additional_rsync_options = '--opt-a --opt-b'

        rsync.directories do |directory|
          directory.add '/some/directory/'
          directory.add '~/home/directory'
        end
      end

      FileUtils.expects(:mkdir_p).with(File.expand_path('~/my_backups/'))

      syncer.expects(:run).with(
        "rsync --archive --opt-a --opt-b " +
        "'/some/directory' '#{ File.expand_path('~/home/directory') }' " +
        "'#{ File.expand_path('~/my_backups') }'"
      )

      syncer.perform!
    end

    specify 'with mirror, excludes and additional_rsync_options' do
      syncer = Syncer::RSync::Local.new do |rsync|
        rsync.path    = '~/my_backups'
        rsync.mirror  = true
        rsync.additional_rsync_options = ['--opt-a', '--opt-b']

        rsync.directories do |directory|
          directory.add '/some/directory/'
          directory.add '~/home/directory'
          directory.exclude '*~'
          directory.exclude 'tmp/'
        end
      end

      FileUtils.expects(:mkdir_p).with(File.expand_path('~/my_backups/'))

      syncer.expects(:run).with(
        "rsync --archive --delete --exclude='*~' --exclude='tmp/' " +
        "--opt-a --opt-b " +
        "'/some/directory' '#{ File.expand_path('~/home/directory') }' " +
        "'#{ File.expand_path('~/my_backups') }'"
      )

      syncer.perform!
    end

    describe 'logging messages' do
      it 'logs started/finished messages' do
        syncer = Syncer::RSync::Local.new

        Logger.expects(:info).with('Syncer::RSync::Local Started...')
        Logger.expects(:info).with('Syncer::RSync::Local Finished!')
        syncer.perform!
      end

      it 'logs messages using optional syncer_id' do
        syncer = Syncer::RSync::Local.new('My Syncer')

        Logger.expects(:info).with('Syncer::RSync::Local (My Syncer) Started...')
        Logger.expects(:info).with('Syncer::RSync::Local (My Syncer) Finished!')
        syncer.perform!
      end
    end

  end # describe '#perform!'

  describe 'deprecations' do

    describe '#additional_options' do
      before do
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use #additional_rsync_options instead/
          )
        }
      end

      context 'when set directly' do
        it 'warns and transfers option value' do
          syncer = Syncer::RSync::Local.new do |s|
            s.additional_options = ['some', 'options']
          end
          expect( syncer.additional_rsync_options ).to eq ['some', 'options']
        end
      end

      context 'when set using defaults' do
        after { Syncer::RSync::Local.clear_defaults! }

        it 'warns and transfers option value' do
          Syncer::RSync::Local.defaults do |s|
            s.additional_options = ['some', 'defaults']
          end
          syncer = Syncer::RSync::Local.new
          expect( syncer.additional_rsync_options ).to eq ['some', 'defaults']
        end
      end

    end # describe '#additional_options'

  end # describe 'deprecations'
end
end
