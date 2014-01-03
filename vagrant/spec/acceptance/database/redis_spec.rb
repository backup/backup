# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

# NOTE: These tests will fail on the current backup-testbox (v7).
# They've been updated to run against redis-2.6.16.
# http://koji.fedoraproject.org/koji/buildinfo?buildID=462509
# The current backup-testbox is running redis-2.4.10.
# This will be fixed in the next backup-testbox update.
module Backup
describe 'Database::Redis' do

  shared_examples 'redis specs' do

    specify 'No Compression' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database Redis do |db|
            db.mode = #{ mode }
            db.rdb_path = '/var/lib/redis/dump.rdb'
            db.invoke_save = #{ invoke_save }
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        5782  my_backup/databases/Redis.rdb
      ])
    end

    specify 'With Compression' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database Redis do |db|
            db.mode = #{ mode }
            db.rdb_path = '/var/lib/redis/dump.rdb'
            db.invoke_save = #{ invoke_save }
          end
          compress_with Gzip
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        2200..2250  my_backup/databases/Redis.rdb.gz
      ])
    end

    specify 'Multiple Dumps' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          database Redis, :dump_01 do |db|
            db.mode = #{ mode }
            db.rdb_path = '/var/lib/redis/dump.rdb'
            db.invoke_save = #{ invoke_save }
          end
          database Redis, 'Dump #2' do |db|
            db.mode = #{ mode }
            db.rdb_path = '/var/lib/redis/dump.rdb'
            db.invoke_save = #{ invoke_save }
          end
          store_with Local
        end
      EOS

      job = backup_perform :my_backup

      expect( job.package.exist? ).to be_true
      expect( job.package ).to match_manifest(%q[
        5782  my_backup/databases/Redis-dump_01.rdb
        5782  my_backup/databases/Redis-Dump__2.rdb
      ])
    end

  end # shared_examples 'redis specs'

  context 'using :copy mode' do
    let(:mode) { ':copy' }

    context 'with :invoke_save' do
      let(:invoke_save) { 'true' }
      include_examples 'redis specs'
    end

    context 'without :invoke_save' do
      let(:invoke_save) { 'false' }
      include_examples 'redis specs'
    end
  end

  context 'using :sync mode' do
    let(:mode) { ':sync' }
    let(:invoke_save) { 'false' }
    include_examples 'redis specs'
  end

end
end
