# encoding: utf-8

require File.expand_path('../../spec_helper', __FILE__)

module Backup
describe Archive do

  shared_examples 'GNU or BSD tar' do

    specify 'All directories, no compression, with/without :root' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          archive :archive_a do |archive|
            archive.add '~/test_data'
          end

          archive :archive_b do |archive|
            archive.root '~/'
            archive.add 'test_data'
          end

          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true

      expect( job.package ).to match_manifest(%q[
        1_105_920 my_backup/archives/archive_a.tar
        1_105_920 my_backup/archives/archive_b.tar
      ])

      # without :root option
      package_a = job.package['my_backup/archives/archive_a.tar']
      expect( package_a ).to match_manifest(%q[
        5_000 /home/vagrant/test_data/dir_a/file_a
        5_000 /home/vagrant/test_data/dir_a/file_b
        5_000 /home/vagrant/test_data/dir_a/file_c

        10_000 /home/vagrant/test_data/dir_b/file_a
        10_000 /home/vagrant/test_data/dir_b/file_b
        10_000 /home/vagrant/test_data/dir_b/file_c

        15_000 /home/vagrant/test_data/dir_c/file_a
        15_000 /home/vagrant/test_data/dir_c/file_b
        15_000 /home/vagrant/test_data/dir_c/file_c

        1_000_000 /home/vagrant/test_data/dir_d/file_a
      ])

      # with :root option
      package_b = job.package['my_backup/archives/archive_b.tar']
      expect( package_b ).to match_manifest(%q[
        5_000 test_data/dir_a/file_a
        5_000 test_data/dir_a/file_b
        5_000 test_data/dir_a/file_c

        10_000 test_data/dir_b/file_a
        10_000 test_data/dir_b/file_b
        10_000 test_data/dir_b/file_c

        15_000 test_data/dir_c/file_a
        15_000 test_data/dir_c/file_b
        15_000 test_data/dir_c/file_c

        1_000_000 test_data/dir_d/file_a
      ])
    end

    specify 'Specific directories, with compression, with/without :root' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          archive :archive_a do |archive|
            archive.add '~/test_data/dir_a/'
            archive.add '~/test_data/dir_b'
          end

          archive :archive_b do |archive|
            archive.root '~/test_data'
            archive.add 'dir_a/'
            archive.add 'dir_b'
          end

          compress_with Gzip

          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        - my_backup/archives/archive_a.tar.gz
        - my_backup/archives/archive_b.tar.gz
      ])

      # without :root option
      package_a = job.package['my_backup/archives/archive_a.tar.gz']
      expect( package_a ).to match_manifest(%q[
        5_000 /home/vagrant/test_data/dir_a/file_a
        5_000 /home/vagrant/test_data/dir_a/file_b
        5_000 /home/vagrant/test_data/dir_a/file_c

        10_000 /home/vagrant/test_data/dir_b/file_a
        10_000 /home/vagrant/test_data/dir_b/file_b
        10_000 /home/vagrant/test_data/dir_b/file_c
      ])

      # with :root option
      package_b = job.package['my_backup/archives/archive_b.tar.gz']
      expect( package_b ).to match_manifest(%q[
        5_000 dir_a/file_a
        5_000 dir_a/file_b
        5_000 dir_a/file_c

        10_000 dir_b/file_a
        10_000 dir_b/file_b
        10_000 dir_b/file_c
      ])
    end

    specify 'Excluded directories, with compression, with/without :root' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          archive :archive_a do |archive|
            archive.add '~/test_data'
            archive.exclude '~/test_data/dir_a/'
            archive.exclude '~/test_data/dir_d'
          end

          archive :archive_b do |archive|
            archive.root '~/'
            archive.add 'test_data'
            archive.exclude 'test_data/dir_a/*'
            archive.exclude 'test_data/dir_d'
          end

          compress_with Gzip

          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        - my_backup/archives/archive_a.tar.gz
        - my_backup/archives/archive_b.tar.gz
      ])

      # without :root option
      package_a = job.package['my_backup/archives/archive_a.tar.gz']
      expect( package_a ).to match_manifest(%q[
        10_000 /home/vagrant/test_data/dir_b/file_a
        10_000 /home/vagrant/test_data/dir_b/file_b
        10_000 /home/vagrant/test_data/dir_b/file_c

        15_000 /home/vagrant/test_data/dir_c/file_a
        15_000 /home/vagrant/test_data/dir_c/file_b
        15_000 /home/vagrant/test_data/dir_c/file_c
      ])

      # with :root option
      package_b = job.package['my_backup/archives/archive_b.tar.gz']
      expect( package_b ).to match_manifest(%q[
        10_000 test_data/dir_b/file_a
        10_000 test_data/dir_b/file_b
        10_000 test_data/dir_b/file_c

        15_000 test_data/dir_c/file_a
        15_000 test_data/dir_c/file_b
        15_000 test_data/dir_c/file_c
      ])
    end

    specify 'Using Splitter' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          split_into_chunks_of 1 # 1MB

          archive :my_archive do |archive|
            archive.add '~/test_data'
          end

          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.files.count ).to be(2)

      expect( job.package ).to match_manifest(%q[
        1_105_920 my_backup/archives/my_archive.tar
      ])

      expect(
        job.package['my_backup/archives/my_archive.tar']
      ).to match_manifest(<<-EOS)
        5_000 /home/vagrant/test_data/dir_a/file_a
        5_000 /home/vagrant/test_data/dir_a/file_b
        5_000 /home/vagrant/test_data/dir_a/file_c

        10_000 /home/vagrant/test_data/dir_b/file_a
        10_000 /home/vagrant/test_data/dir_b/file_b
        10_000 /home/vagrant/test_data/dir_b/file_c

        15_000 /home/vagrant/test_data/dir_c/file_a
        15_000 /home/vagrant/test_data/dir_c/file_b
        15_000 /home/vagrant/test_data/dir_c/file_c

        1_000_000 /home/vagrant/test_data/dir_d/file_a
      EOS
    end

    specify 'Using sudo' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          archive :my_archive do |archive|
            archive.use_sudo
            archive.add '~/test_root_data'
          end

          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        - my_backup/archives/my_archive.tar
      ])

      expect(
        job.package['my_backup/archives/my_archive.tar']
      ).to match_manifest(<<-EOS)
        5_000 /home/vagrant/test_root_data/dir_a/file_a
        5_000 /home/vagrant/test_root_data/dir_a/file_b
        5_000 /home/vagrant/test_root_data/dir_a/file_c
      EOS
    end


  end # shared_examples 'GNU or BSD tar'

  describe 'Using GNU tar' do
    # GNU tar is set as the default
    it_behaves_like 'GNU or BSD tar'

    it 'detects GNU tar' do
      create_config <<-EOS
        Backup::Utilities.configure do
          tar '/usr/bin/tar'
          tar_dist nil
        end
      EOS

      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          archive :my_archive do |archive|
            archive.add '~/test_data/dir_a'
          end
        end
      EOS

      job = backup_perform :my_backup

      log_messages = job.logger.messages.map(&:lines).flatten.join
      expect( log_messages ).to match(/STDOUT: tar \(GNU tar\)/)
      expect( Utilities.send(:utility, :tar) ).to eq('/usr/bin/tar')
      expect( Utilities.send(:gnu_tar?) ).to be(true)
    end
  end

  describe 'Using BSD tar' do
    before do
      # tar_dist must be set, since the default config.rb
      # will set this to :gnu to suppress the detection messages.
      create_config <<-EOS
        Backup::Utilities.configure do
          tar '/usr/bin/bsdtar'
          tar_dist :bsd
        end
      EOS
    end

    it_behaves_like 'GNU or BSD tar'

    it 'detects BSD tar' do
      create_config <<-EOS
        Backup::Utilities.configure do
          tar '/usr/bin/bsdtar'
          tar_dist nil
        end
      EOS

      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          archive :my_archive do |archive|
            archive.add '~/test_data/dir_a'
          end
        end
      EOS

      job = backup_perform :my_backup

      log_messages = job.logger.messages.map(&:lines).flatten.join
      expect( log_messages ).to match(/STDOUT: bsdtar/)
      expect( Utilities.send(:utility, :tar) ).to eq('/usr/bin/bsdtar')
      expect( Utilities.send(:gnu_tar?) ).to be(false)
    end
  end

end
end
