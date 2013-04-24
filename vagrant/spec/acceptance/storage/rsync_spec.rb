# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

module Backup
describe Storage::RSync do

  context 'using local operation' do
    specify 'single package file' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          archive :my_archive do |archive|
            archive.add '~/test_data'
          end

          store_with RSync do |rsync|
            rsync.path = '~/Storage'

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true

      expect( job.package ).to match_manifest(%q[
        1_105_920 my_backup/archives/my_archive.tar
      ])
    end

    specify 'multiple package files' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          split_into_chunks_of 1 # 1MB

          archive :my_archive do |archive|
            archive.add '~/test_data'
          end

          store_with RSync do |rsync|
            rsync.path = '~/Storage'

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.files.count ).to be(2)

      expect( job.package ).to match_manifest(%q[
        1_105_920 my_backup/archives/my_archive.tar
      ])
    end
  end # context 'using local operation'

  context 'using :ssh mode' do
    specify 'single package file' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          archive :my_archive do |archive|
            archive.add '~/test_data'
          end

          store_with RSync do |rsync|
            rsync.host = 'localhost'
            rsync.path = '~/Storage'

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true

      expect( job.package ).to match_manifest(%q[
        1_105_920 my_backup/archives/my_archive.tar
      ])
    end

    specify 'multiple package files' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          split_into_chunks_of 1 # 1MB

          archive :my_archive do |archive|
            archive.add '~/test_data'
          end

          store_with RSync do |rsync|
            rsync.host = 'localhost'
            rsync.path = '~/Storage'

            rsync.additional_rsync_options = '-vv'
          end
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.files.count ).to be(2)

      expect( job.package ).to match_manifest(%q[
        1_105_920 my_backup/archives/my_archive.tar
      ])
    end
  end # context 'using :ssh mode'

  context 'daemon modes' do
    before do
      # Note: rsync will not automatically create this directory,
      # since the target is a file. Normally when using a daemon mode,
      # only a module name would be used which would specify a directory
      # that already exists in which to store the backup package file(s).
      # But we need to use ~/Storage, which we remove before each spec example.
      FileUtils.mkdir BackupSpec::LOCAL_STORAGE_PATH
    end

    context 'using :ssh_daemon mode' do
      specify 'single package file' do
        create_model :my_backup, <<-EOS
          Backup::Model.new(:my_backup, 'a description') do
            archive :my_archive do |archive|
              archive.add '~/test_data'
            end

            store_with RSync do |rsync|
              rsync.mode = :ssh_daemon
              rsync.host = 'localhost'
              rsync.path = 'ssh-daemon-module/Storage'

              rsync.additional_rsync_options = '-vv'
            end
          end
        EOS

        job = backup_perform :my_backup

        expect( job.package.exist? ).to be_true

        expect( job.package ).to match_manifest(%q[
          1_105_920 my_backup/archives/my_archive.tar
        ])
      end

      specify 'multiple package files' do
        create_model :my_backup, <<-EOS
          Backup::Model.new(:my_backup, 'a description') do
            split_into_chunks_of 1 # 1MB

            archive :my_archive do |archive|
              archive.add '~/test_data'
            end

            store_with RSync do |rsync|
              rsync.mode = :ssh_daemon
              rsync.host = 'localhost'
              rsync.path = 'ssh-daemon-module/Storage'

              rsync.additional_rsync_options = '-vv'
            end
          end
        EOS

        job = backup_perform :my_backup

        expect( job.package.files.count ).to be(2)

        expect( job.package ).to match_manifest(%q[
          1_105_920 my_backup/archives/my_archive.tar
        ])
      end
    end # context 'using :ssh_daemon mode'

    context 'using :rsync_daemon mode' do
      specify 'single package file' do
        create_model :my_backup, <<-EOS
          Backup::Model.new(:my_backup, 'a description') do
            archive :my_archive do |archive|
              archive.add '~/test_data'
            end

            store_with RSync do |rsync|
              rsync.mode = :rsync_daemon
              rsync.host = 'localhost'
              rsync.rsync_password = 'daemon-password'
              rsync.path = 'rsync-daemon-module/Storage'

              rsync.additional_rsync_options = '-vv'
            end
          end
        EOS

        job = backup_perform :my_backup

        expect( job.package.exist? ).to be_true

        expect( job.package ).to match_manifest(%q[
          1_105_920 my_backup/archives/my_archive.tar
        ])
      end

      specify 'multiple package files' do
        create_model :my_backup, <<-EOS
          Backup::Model.new(:my_backup, 'a description') do
            split_into_chunks_of 1 # 1MB

            archive :my_archive do |archive|
              archive.add '~/test_data'
            end

            store_with RSync do |rsync|
              rsync.mode = :rsync_daemon
              rsync.host = 'localhost'
              rsync.rsync_password = 'daemon-password'
              rsync.path = 'rsync-daemon-module/Storage'

              rsync.additional_rsync_options = '-vv'
            end
          end
        EOS

        job = backup_perform :my_backup

        expect( job.package.files.count ).to be(2)

        expect( job.package ).to match_manifest(%q[
          1_105_920 my_backup/archives/my_archive.tar
        ])
      end
    end # context 'using :rsync_daemon mode'

  end # context 'daemon modes'

end
end
