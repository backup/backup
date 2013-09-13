# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

module Backup
describe 'Database::Riak' do

  specify 'No Compression' do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        database Riak
        store_with Local
      end
    EOS

    # --tmp-path must be changed from the default ~/Backup/.tmp
    # due to permissions needed by riak-admin to perform the dump.
    job = backup_perform :my_backup, '--tmp-path=/tmp'

    expect( job.package.exist? ).to be_true
    expect( job.package ).to match_manifest(%q[
      156000..157000 my_backup/databases/Riak-riak@127.0.0.1
    ])
  end

  specify 'With Compression' do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        database Riak
        store_with Local
        compress_with Gzip
      end
    EOS

    # --tmp-path must be changed from the default ~/Backup/.tmp
    # due to permissions needed by riak-admin to perform the dump.
    job = backup_perform :my_backup, '--tmp-path=/tmp'

    expect( job.package.exist? ).to be_true
    expect( job.package ).to match_manifest(%q[
      6500..6700 my_backup/databases/Riak-riak@127.0.0.1.gz
    ])
  end
end
end
