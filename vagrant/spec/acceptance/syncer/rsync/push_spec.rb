# encoding: utf-8

require File.expand_path('../../../../spec_helper', __FILE__)

module Backup
describe Syncer::RSync::Push do

  context 'using :ssh mode' do
    specify 'single directory' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          sync_with RSync::Push do |rsync|
            rsync.host = 'localhost'
            rsync.path = '~/Storage'

            rsync.directories do |dirs|
              dirs.add '~/test_data'
            end

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      backup_perform :my_backup

      expect( dir_contents('~/Storage/test_data') ).
          to eq( dir_contents('~/test_data') )
    end

    specify 'multiple directories' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          sync_with RSync::Push do |rsync|
            rsync.host = 'localhost'
            rsync.path = '~/Storage'

            rsync.directories do |dirs|
              dirs.add '~/test_data/dir_a'
              dirs.add '~/test_data/dir_b'
              dirs.add '~/test_data/dir_c'
            end

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      backup_perform :my_backup

      expect( dir_contents('~/Storage/dir_a') ).
          to eq( dir_contents('~/test_data/dir_a') )
      expect( dir_contents('~/Storage/dir_b') ).
          to eq( dir_contents('~/test_data/dir_b') )
      expect( dir_contents('~/Storage/dir_c') ).
          to eq( dir_contents('~/test_data/dir_c') )
    end

    specify 'multiple directories with excludes' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          sync_with RSync::Push do |rsync|
            rsync.host = 'localhost'
            rsync.path = '~/Storage'

            rsync.directories do |dirs|
              dirs.add '~/test_data/dir_a'
              dirs.add '~/test_data/dir_b'
              dirs.add '~/test_data/dir_c'
              dirs.exclude 'file_b'
            end

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      backup_perform :my_backup

      expect( dir_contents('~/Storage/dir_a') ).to eq(
        dir_contents('~/test_data/dir_a') - ['/file_b']
      )
      expect( dir_contents('~/Storage/dir_b') ).to eq(
        dir_contents('~/test_data/dir_b') - ['/file_b']
      )
      expect( dir_contents('~/Storage/dir_c') ).to eq(
        dir_contents('~/test_data/dir_c') - ['/file_b']
      )
    end
  end # context 'using :ssh mode'

  context 'using :ssh_daemon mode' do
    specify 'single directory' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          sync_with RSync::Push do |rsync|
            rsync.mode = :ssh_daemon
            rsync.host = 'localhost'
            rsync.path = 'ssh-daemon-module/Storage'

            rsync.directories do |dirs|
              dirs.add '~/test_data'
            end

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      backup_perform :my_backup

      expect( dir_contents('~/Storage/test_data') ).
          to eq( dir_contents('~/test_data') )
    end

    specify 'multiple directories' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          sync_with RSync::Push do |rsync|
            rsync.mode = :ssh_daemon
            rsync.host = 'localhost'
            rsync.path = 'ssh-daemon-module/Storage'

            rsync.directories do |dirs|
              dirs.add '~/test_data/dir_a'
              dirs.add '~/test_data/dir_b'
              dirs.add '~/test_data/dir_c'
            end

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      backup_perform :my_backup

      expect( dir_contents('~/Storage/dir_a') ).
          to eq( dir_contents('~/test_data/dir_a') )
      expect( dir_contents('~/Storage/dir_b') ).
          to eq( dir_contents('~/test_data/dir_b') )
      expect( dir_contents('~/Storage/dir_c') ).
          to eq( dir_contents('~/test_data/dir_c') )
    end

    specify 'multiple directories with excludes' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          sync_with RSync::Push do |rsync|
            rsync.mode = :ssh_daemon
            rsync.host = 'localhost'
            rsync.path = 'ssh-daemon-module/Storage'

            rsync.directories do |dirs|
              dirs.add '~/test_data/dir_a'
              dirs.add '~/test_data/dir_b'
              dirs.add '~/test_data/dir_c'
              dirs.exclude 'file_b'
            end

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      backup_perform :my_backup

      expect( dir_contents('~/Storage/dir_a') ).to eq(
        dir_contents('~/test_data/dir_a') - ['/file_b']
      )
      expect( dir_contents('~/Storage/dir_b') ).to eq(
        dir_contents('~/test_data/dir_b') - ['/file_b']
      )
      expect( dir_contents('~/Storage/dir_c') ).to eq(
        dir_contents('~/test_data/dir_c') - ['/file_b']
      )
    end
  end # context 'using :ssh_daemon mode'

  context 'using :rsync_daemon mode' do
    specify 'single directory' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          sync_with RSync::Push do |rsync|
            rsync.mode = :rsync_daemon
            rsync.host = 'localhost'
            rsync.rsync_password = 'daemon-password'
            rsync.path = 'rsync-daemon-module/Storage'

            rsync.directories do |dirs|
              dirs.add '~/test_data'
            end

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      backup_perform :my_backup

      expect( dir_contents('~/Storage/test_data') ).
          to eq( dir_contents('~/test_data') )
    end

    specify 'multiple directories' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          sync_with RSync::Push do |rsync|
            rsync.mode = :rsync_daemon
            rsync.host = 'localhost'
            rsync.rsync_password = 'daemon-password'
            rsync.path = 'rsync-daemon-module/Storage'

            rsync.directories do |dirs|
              dirs.add '~/test_data/dir_a'
              dirs.add '~/test_data/dir_b'
              dirs.add '~/test_data/dir_c'
            end

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      backup_perform :my_backup

      expect( dir_contents('~/Storage/dir_a') ).
          to eq( dir_contents('~/test_data/dir_a') )
      expect( dir_contents('~/Storage/dir_b') ).
          to eq( dir_contents('~/test_data/dir_b') )
      expect( dir_contents('~/Storage/dir_c') ).
          to eq( dir_contents('~/test_data/dir_c') )
    end

    specify 'multiple directories with excludes' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          sync_with RSync::Push do |rsync|
            rsync.mode = :rsync_daemon
            rsync.host = 'localhost'
            rsync.rsync_password = 'daemon-password'
            rsync.path = 'rsync-daemon-module/Storage'

            rsync.directories do |dirs|
              dirs.add '~/test_data/dir_a'
              dirs.add '~/test_data/dir_b'
              dirs.add '~/test_data/dir_c'
              dirs.exclude 'file_b'
            end

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      backup_perform :my_backup

      expect( dir_contents('~/Storage/dir_a') ).to eq(
        dir_contents('~/test_data/dir_a') - ['/file_b']
      )
      expect( dir_contents('~/Storage/dir_b') ).to eq(
        dir_contents('~/test_data/dir_b') - ['/file_b']
      )
      expect( dir_contents('~/Storage/dir_c') ).to eq(
        dir_contents('~/test_data/dir_c') - ['/file_b']
      )
    end
  end # context 'using :rsync_daemon mode'

end
end
