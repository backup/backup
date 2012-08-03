##
# Models

Backup::Model.new(:archive_local, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  store_with Local
end

Backup::Model.new(:archive_scp, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  store_with SCP
end

# To initialize the Dropbox session cache, run manually first using:
# VERBOSE=1 rspec spec-live/storage/dropbox_spec.rb --tag init
Backup::Model.new(:archive_dropbox, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  store_with Dropbox
end

Backup::Model.new(:compressor_gzip_archive_local, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  compress_with Gzip
  store_with Local
end

Backup::Model.new(:compressor_custom_archive_local, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  compress_with Custom do |c|
    c.command = 'gzip -1'
    c.extension = '.foo'
  end
  store_with Local
end

Backup::Model.new(:notifier_mail, 'test_label') do
  notify_by Mail
end

Backup::Model.new(:notifier_mail_file, 'test_label') do
  notify_by Mail do |mail|
    mail.to = 'test@backup'
    mail.delivery_method = :file
  end
end

Backup::Model.new(:syncer_cloud_s3, 'test_label') do
  sync_with Cloud::S3 do |s3|
    s3.directories do
      add File.join(SpecLive::SYNC_PATH, 'dir_a')
      add File.join(SpecLive::SYNC_PATH, 'dir_b')
    end
  end
end
