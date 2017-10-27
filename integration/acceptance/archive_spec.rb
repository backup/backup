# encoding: utf-8

require File.expand_path("../../spec_helper", __FILE__)

module Backup
  describe Archive do
    specify "All directories, no compression, without :root" do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          archive :archive_a do |archive|
            archive.add "./tmp/test_data"
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect(job.package.exist?).to be true

      expect(job.package).to match_manifest(<<-EOS)
        10_496_000 my_backup/archives/archive_a.tar
      EOS

      package_a = job.package["my_backup/archives/archive_a.tar"]
      expect(package_a).to match_manifest(<<-EOS)
        1_048_576 /usr/src/backup/tmp/test_data/dir_a/1.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_a/2.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_a/3.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_b/1.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_b/2.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_b/3.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_c/1.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_c/2.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_c/3.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_d/1.txt
      EOS
    end

    specify "Specific directories, with compression, with/without :root" do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, "a description") do
          archive :archive_a do |archive|
            archive.add "./tmp/test_data/dir_a/"
            archive.add "./tmp/test_data/dir_b"
          end

          archive :archive_b do |archive|
            archive.root "./tmp/test_data"
            archive.add "dir_a/"
            archive.add "dir_b"
          end

          compress_with Gzip

          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect(job.package.exist?).to be true
      expect(job.package).to match_manifest(<<-EOS)
        - my_backup/archives/archive_a.tar.gz
        - my_backup/archives/archive_b.tar.gz
      EOS

      package_a = job.package["my_backup/archives/archive_a.tar.gz"]
      expect(package_a).to match_manifest(<<-EOS)
        1_048_576 /usr/src/backup/tmp/test_data/dir_a/1.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_a/2.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_a/3.txt

        1_048_576 /usr/src/backup/tmp/test_data/dir_b/1.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_b/2.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_b/3.txt
      EOS
    end

    specify "Using Splitter" do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, "a description") do
          split_into_chunks_of 1 # 1MB

          archive :my_archive do |archive|
            archive.add "./tmp/test_data"
          end

          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect(job.package.files.count).to be(11)

      expect(job.package).to match_manifest(
        "10_496_000 my_backup/archives/my_archive.tar"
      )

      expect(
        job.package["my_backup/archives/my_archive.tar"]
      ).to match_manifest(<<-EOS)
        1_048_576 /usr/src/backup/tmp/test_data/dir_a/1.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_a/2.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_a/3.txt

        1_048_576 /usr/src/backup/tmp/test_data/dir_b/1.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_b/2.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_b/3.txt

        1_048_576 /usr/src/backup/tmp/test_data/dir_c/1.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_c/2.txt
        1_048_576 /usr/src/backup/tmp/test_data/dir_c/3.txt

        1_048_576 /usr/src/backup/tmp/test_data/dir_d/1.txt
      EOS
    end
  end
end
