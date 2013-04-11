# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

module Backup
describe Syncer::RSync::Pull do
  before do
    Syncer::RSync::Pull.any_instance.
        stubs(:utility).with(:rsync).returns('rsync')
    Syncer::RSync::Pull.any_instance.
        stubs(:utility).with(:ssh).returns('ssh')
  end

  describe '#perform!' do

    describe 'pulling from the remote host' do

      specify 'using :ssh mode' do
        syncer = Syncer::RSync::Pull.new do |s|
          s.mode = :ssh
          s.host = 'my_host'
          s.path = '~/some/path/'
          s.directories do |dirs|
            dirs.add '/this/dir/'
            dirs.add 'that/dir'
            dirs.add '~/home/dir/'
          end
        end

        FileUtils.expects(:mkdir_p).with(File.expand_path('~/some/path/'))

        syncer.expects(:run).with(
          "rsync --archive -e \"ssh -p 22\" " +
          "my_host:'/this/dir' :'that/dir' :'home/dir' " +
          "'#{ File.expand_path('~/some/path/') }'"
        )
        syncer.perform!
      end

      specify 'using :ssh_daemon mode' do
        syncer = Syncer::RSync::Pull.new do |s|
          s.mode = :ssh_daemon
          s.host = 'my_host'
          s.path = '~/some/path/'
          s.directories do |dirs|
            dirs.add '/this/dir/'
            dirs.add 'that/dir'
            dirs.add '~/home/dir/'
          end
        end

        FileUtils.expects(:mkdir_p).with(File.expand_path('~/some/path/'))

        syncer.expects(:run).with(
          "rsync --archive -e \"ssh -p 22\" " +
          "my_host::'/this/dir' ::'that/dir' ::'home/dir' " +
          "'#{ File.expand_path('~/some/path/') }'"
        )
        syncer.perform!
      end

      specify 'using :rsync_daemon mode' do
        syncer = Syncer::RSync::Pull.new do |s|
          s.mode = :rsync_daemon
          s.host = 'my_host'
          s.path = '~/some/path/'
          s.directories do |dirs|
            dirs.add '/this/dir/'
            dirs.add 'that/dir'
            dirs.add '~/home/dir/'
          end
        end

        FileUtils.expects(:mkdir_p).with(File.expand_path('~/some/path/'))

        syncer.expects(:run).with(
          "rsync --archive --port 873 " +
          "my_host::'/this/dir' ::'that/dir' ::'home/dir' " +
          "'#{ File.expand_path('~/some/path/') }'"
        )
        syncer.perform!
      end

    end # describe 'pulling from the remote host'

    describe 'password handling' do
      let(:s) { sequence '' }
      let(:syncer) { Syncer::RSync::Pull.new }

      it 'writes and removes the temporary password file' do
        syncer.expects(:write_password_file!).in_sequence(s)
        syncer.expects(:run).in_sequence(s)
        syncer.expects(:remove_password_file!).in_sequence(s)

        syncer.perform!
      end

      it 'ensures temporary password file removal' do
        syncer.expects(:write_password_file!).in_sequence(s)
        syncer.expects(:run).in_sequence(s).raises('error')
        syncer.expects(:remove_password_file!).in_sequence(s)

        expect do
          syncer.perform!
        end.to raise_error
      end
    end # describe 'password handling'

    describe 'logging messages' do
      it 'logs started/finished messages' do
        syncer = Syncer::RSync::Pull.new

        Logger.expects(:info).with('Syncer::RSync::Pull Started...')
        Logger.expects(:info).with('Syncer::RSync::Pull Finished!')
        syncer.perform!
      end

      it 'logs messages using optional syncer_id' do
        syncer = Syncer::RSync::Pull.new('My Syncer')

        Logger.expects(:info).with('Syncer::RSync::Pull (My Syncer) Started...')
        Logger.expects(:info).with('Syncer::RSync::Pull (My Syncer) Finished!')
        syncer.perform!
      end
    end
  end # describe '#perform!'

  # same deprecations as RSync::Push
end
end
