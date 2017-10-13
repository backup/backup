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
  end
end
