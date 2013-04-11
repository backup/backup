# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

module Backup
describe 'Database::MongoDB' do

  describe 'Single Database' do

    specify 'All collections' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database MongoDB do |db|
            db.name = 'backup_test_01'
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true

      expect( job.package ).to match_manifest(%q[
        - my_backup/databases/MongoDB.tar
      ])

      expect(
        job.package['my_backup/databases/MongoDB.tar']
      ).to match_manifest(%q[
         3400  MongoDB/backup_test_01/ones.bson
          101  MongoDB/backup_test_01/ones.metadata.json
         6800  MongoDB/backup_test_01/twos.bson
          101  MongoDB/backup_test_01/twos.metadata.json
        13600  MongoDB/backup_test_01/threes.bson
          103  MongoDB/backup_test_01/threes.metadata.json
      ])
    end

    specify 'All collections with compression' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database MongoDB do |db|
            db.name = 'backup_test_01'
          end
          compress_with Gzip
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true

      expect( job.package ).to match_manifest(%q[
        - my_backup/databases/MongoDB.tar.gz
      ])

      expect(
        job.package['my_backup/databases/MongoDB.tar.gz']
      ).to match_manifest(%q[
          3400  MongoDB/backup_test_01/ones.bson
          101   MongoDB/backup_test_01/ones.metadata.json
          6800  MongoDB/backup_test_01/twos.bson
          101   MongoDB/backup_test_01/twos.metadata.json
        13600   MongoDB/backup_test_01/threes.bson
          103   MongoDB/backup_test_01/threes.metadata.json
      ])
    end

    specify 'All collections, locking the database' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database MongoDB do |db|
            db.name = 'backup_test_01'
            db.lock = true
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true

      expect( job.package ).to match_manifest(%q[
        - my_backup/databases/MongoDB.tar
      ])

      expect(
        job.package['my_backup/databases/MongoDB.tar']
      ).to match_manifest(%q[
         3400  MongoDB/backup_test_01/ones.bson
          101  MongoDB/backup_test_01/ones.metadata.json
         6800  MongoDB/backup_test_01/twos.bson
          101  MongoDB/backup_test_01/twos.metadata.json
        13600  MongoDB/backup_test_01/threes.bson
          103  MongoDB/backup_test_01/threes.metadata.json
      ])
    end

  end # describe 'Single Database'

  describe 'All Databases' do

    specify 'All collections' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database MongoDB
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true

      expect( job.package ).to match_manifest(%q[
        - my_backup/databases/MongoDB.tar
      ])

      expect(
        job.package['my_backup/databases/MongoDB.tar']
      ).to match_manifest(%q[
         3400  MongoDB/backup_test_01/ones.bson
          101  MongoDB/backup_test_01/ones.metadata.json
         6800  MongoDB/backup_test_01/twos.bson
          101  MongoDB/backup_test_01/twos.metadata.json
        13600  MongoDB/backup_test_01/threes.bson
          103  MongoDB/backup_test_01/threes.metadata.json

         4250  MongoDB/backup_test_02/ones.bson
          101  MongoDB/backup_test_02/ones.metadata.json
         7650  MongoDB/backup_test_02/twos.bson
          101  MongoDB/backup_test_02/twos.metadata.json
        14450  MongoDB/backup_test_02/threes.bson
          103  MongoDB/backup_test_02/threes.metadata.json
      ])
    end

    specify 'All collections, locking the database' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database MongoDB do |db|
            db.lock = true
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true

      expect( job.package ).to match_manifest(%q[
        - my_backup/databases/MongoDB.tar
      ])

      expect(
        job.package['my_backup/databases/MongoDB.tar']
      ).to match_manifest(%q[
         3400  MongoDB/backup_test_01/ones.bson
          101  MongoDB/backup_test_01/ones.metadata.json
         6800  MongoDB/backup_test_01/twos.bson
          101  MongoDB/backup_test_01/twos.metadata.json
        13600  MongoDB/backup_test_01/threes.bson
          103  MongoDB/backup_test_01/threes.metadata.json

         4250  MongoDB/backup_test_02/ones.bson
          101  MongoDB/backup_test_02/ones.metadata.json
         7650  MongoDB/backup_test_02/twos.bson
          101  MongoDB/backup_test_02/twos.metadata.json
        14450  MongoDB/backup_test_02/threes.bson
          103  MongoDB/backup_test_02/threes.metadata.json
      ])
    end

  end # describe 'All Databases'

  describe 'Multiple Dumps' do

    specify 'All collections' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database MongoDB, :dump_01 do |db|
            db.name = 'backup_test_01'
          end
          database MongoDB, 'Dump #2' do |db|
            db.name = 'backup_test_02'
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true

      expect( job.package ).to match_manifest(%q[
        - my_backup/databases/MongoDB-dump_01.tar
        - my_backup/databases/MongoDB-Dump__2.tar
      ])

      expect(
        job.package['my_backup/databases/MongoDB-dump_01.tar']
      ).to match_manifest(%q[
         3400  MongoDB-dump_01/backup_test_01/ones.bson
          101  MongoDB-dump_01/backup_test_01/ones.metadata.json
         6800  MongoDB-dump_01/backup_test_01/twos.bson
          101  MongoDB-dump_01/backup_test_01/twos.metadata.json
        13600  MongoDB-dump_01/backup_test_01/threes.bson
          103  MongoDB-dump_01/backup_test_01/threes.metadata.json
      ])

      expect(
        job.package['my_backup/databases/MongoDB-Dump__2.tar']
      ).to match_manifest(%q[
         4250  MongoDB-Dump__2/backup_test_02/ones.bson
          101  MongoDB-Dump__2/backup_test_02/ones.metadata.json
         7650  MongoDB-Dump__2/backup_test_02/twos.bson
          101  MongoDB-Dump__2/backup_test_02/twos.metadata.json
        14450  MongoDB-Dump__2/backup_test_02/threes.bson
          103  MongoDB-Dump__2/backup_test_02/threes.metadata.json
      ])
    end
  end # describe 'Multiple Dumps'

end
end
