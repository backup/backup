# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

module Backup
describe 'Database::Redis' do

  specify 'No SAVE, no Compression' do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        database Redis do |db|
          db.path = '/var/lib/redis'
        end
        store_with Local
      end
    EOS

    job = backup_perform :my_backup

    expect( job.package.exist? ).to be_true
    expect( job.package ).to match_manifest(%q[
      5774  my_backup/databases/Redis.rdb
    ])
  end

  specify 'SAVE, no Compression' do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        database Redis do |db|
          db.path = '/var/lib/redis'
          db.invoke_save = true
        end
        store_with Local
      end
    EOS

    job = backup_perform :my_backup

    expect( job.package.exist? ).to be_true
    expect( job.package ).to match_manifest(%q[
      5774  my_backup/databases/Redis.rdb
    ])
  end

  specify 'SAVE, with Compression' do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        database Redis do |db|
          db.path = '/var/lib/redis'
          db.invoke_save = true
        end
        compress_with Gzip
        store_with Local
      end
    EOS

    job = backup_perform :my_backup

    expect( job.package.exist? ).to be_true
    expect( job.package ).to match_manifest(%q[
      1900..1950  my_backup/databases/Redis.rdb.gz
    ])
  end

  specify 'Multiple Dumps' do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        database Redis, :dump_01 do |db|
          db.path = '/var/lib/redis'
        end
        database Redis, 'Dump #2' do |db|
          db.path = '/var/lib/redis'
        end
        store_with Local
      end
    EOS

    job = backup_perform :my_backup

    expect( job.package.exist? ).to be_true
    expect( job.package ).to match_manifest(%q[
      5774  my_backup/databases/Redis-dump_01.rdb
      5774  my_backup/databases/Redis-Dump__2.rdb
    ])
  end

end
end
