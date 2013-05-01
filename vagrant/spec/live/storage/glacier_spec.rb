# encoding: utf-8

# These tests can be used to upload to Glacier,
# then later to remove the archives.
# Note that AWS will charge you for removing archives less than 90 days old.
#
# These should not be run when `--tag live` is used.
# Comment this out and change :live to :focus for the test you wish to run.
__END__

require File.expand_path('../../../spec_helper', __FILE__)

# To run these tests, you need to setup your AWS Glacier credentials in
#   /vagrant/spec/live.yml
#
# It's recommended you use a dedicated Vault for this, like:
#   backup.testing
#
module Backup
describe Storage::Glacier,
    :if => BackupSpec::LIVE['storage']['glacier']['specs_enabled'] == true do

  # Each archive is 1.09 MB (1,090,000).
  # This will create 2 package files (5,242,880 + 207,120).
  # Default chunk_size for multipart upload is 4 MiB.
  # The first package file will use multipart, the second won't.
  it 'stores multiple package files', :live do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        split_into_chunks_of 5 # MiB

        archive :archive_a do |archive|
          archive.add '~/test_data'
        end
        archive :archive_b do |archive|
          archive.add '~/test_data'
        end
        archive :archive_c do |archive|
          archive.add '~/test_data'
        end
        archive :archive_d do |archive|
          archive.add '~/test_data'
        end
        archive :archive_e do |archive|
          archive.add '~/test_data'
        end

        store_with Glacier do |glacier|
          glacier.access_key_id =
              BackupSpec::LIVE['storage']['glacier']['access_key_id']
          glacier.secret_access_key =
              BackupSpec::LIVE['storage']['glacier']['secret_access_key']
          glacier.region = BackupSpec::LIVE['storage']['glacier']['region']
          glacier.vault = BackupSpec::LIVE['storage']['glacier']['vault']
        end
      end
    EOS

    # change data_path so cycle data is not destroyed.
    # use the test below to delete any packages stored by this test.
    backup_perform :my_backup, '--data-path=/home/vagrant/glacier_data'
  end

  # this will store an unused package in the YAML file,
  # and delete any previously stored packages.
  it 'removes the archive', :live do
    model = Backup::Model.new(:my_backup, 'a description')
    storage = Backup::Storage::Glacier.new(model) do |glacier|
      glacier.access_key_id =
          BackupSpec::LIVE['storage']['glacier']['access_key_id']
      glacier.secret_access_key =
          BackupSpec::LIVE['storage']['glacier']['secret_access_key']
      glacier.region = BackupSpec::LIVE['storage']['glacier']['region']
      glacier.vault = BackupSpec::LIVE['storage']['glacier']['vault']
      glacier.keep = 1
    end

    Backup::Config.update(data_path: '/home/vagrant/glacier_data')
    Backup::Storage::Cycler.cycle!(storage)

    # remove the YAML file, which now only contains the unused package.
    FileUtils.rm_r '/home/vagrant/glacier_data'
  end

end
end
