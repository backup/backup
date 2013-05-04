# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

module Backup
describe 'Database::PostgreSQL' do

  describe 'All Databases' do

    specify 'With compression' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database PostgreSQL
          compress_with Gzip
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        3094 my_backup/databases/PostgreSQL.sql.gz
      ])
    end

    specify 'Without compression' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database PostgreSQL
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        21616 my_backup/databases/PostgreSQL.sql
      ])
    end

  end # describe 'All Databases'

  describe 'Single Database' do

    specify 'All tables' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database PostgreSQL do |db|
            db.name = 'backup_test_01'
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        9199 my_backup/databases/PostgreSQL.sql
      ])
    end

    specify 'Only one table' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database PostgreSQL do |db|
            db.name = 'backup_test_01'
            db.only_tables = ['ones']
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        2056 my_backup/databases/PostgreSQL.sql
      ])
    end

    specify 'Exclude a table' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database PostgreSQL do |db|
            db.name = 'backup_test_01'
            db.skip_tables = ['ones']
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        7860 my_backup/databases/PostgreSQL.sql
      ])
    end

  end # describe 'Single Database'

  describe 'Multiple Dumps' do

    specify 'All tables' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database PostgreSQL, :dump_01 do |db|
            db.name = 'backup_test_01'
          end
          database PostgreSQL, 'Dump #2' do |db|
            db.name = 'backup_test_02'
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        9199 my_backup/databases/PostgreSQL-dump_01.sql
        9799 my_backup/databases/PostgreSQL-Dump__2.sql
      ])
    end

  end # describe 'Multiple Dumps'

end
end
