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

Backup::Model.new(:encryptor_gpg_asymmetric, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  encrypt_with GPG do |e|
    # this is the default mode
    # e.mode = :asymmetric

    e.keys = {
      # backup03 public key (email as identifier)
      'backup03@foo.com' => SpecLive::GPGKeys[:backup03][:public],
      # backup04 public key (long key id as identifier)
      '0F45932D3F24426D' => SpecLive::GPGKeys[:backup04][:public]
    }

    # The public keys for backup01 and backup02 will be in the system keyring
    # when this job is run. The public keys for backup03 and backup04 will be
    # imported from :keys above when they are not found in the system keyring.
    e.recipients = [
      # backup01 (short keyid)
      '16325C61',
      # backup02 (key fingerprint)
      'F9A9 9BD8 A570 182F F190  037C 7118 9938 6A6A 175A',
      # backup03 (email)
      'backup03@foo.com',
      # backup04 (long keyid)
      '0F45932D3F24426D'
    ]
  end
  store_with Local
end

Backup::Model.new(:encryptor_gpg_asymmetric_missing, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  encrypt_with GPG do |e|
    e.mode = :asymmetric

    e.keys = {
      'backup02@foo.com' => SpecLive::GPGKeys[:backup02][:public]
    }

    e.recipients = [
      'backup01@foo.com', # in the system
      'backup02@foo.com', # imported from #keys
      'backupfoo@foo.com' # a recipient with no public key
    ]
  end
  store_with Local
end

Backup::Model.new(:encryptor_gpg_asymmetric_fail, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  encrypt_with GPG do |e|
    # this is the default mode
    # e.mode = :asymmetric

    # no recipients have public keys available
    e.recipients = [
      'backupfoo@foo.com',
      'backupfoo2@foo.com'
    ]
  end
  store_with Local
end

Backup::Model.new(:encryptor_gpg_symmetric, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  encrypt_with GPG do |e|
    e.mode = :symmetric
    e.passphrase = 'a secret'
  end
  store_with Local
end

Backup::Model.new(:encryptor_gpg_symmetric_with_config, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  encrypt_with GPG do |e|
    e.mode = :symmetric
    e.passphrase = 'a secret'
    e.gpg_config = <<-EOS
      personal-cipher-preferences AES256 CAST5
    EOS
  end
  store_with Local
end

Backup::Model.new(:encryptor_gpg_both, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  encrypt_with GPG do |e|
    e.mode = :both
    e.passphrase = 'a secret'

    e.keys = {
      # backup03 public key (email as identifier)
      'backup03@foo.com' => SpecLive::GPGKeys[:backup03][:public]
    }

    # The public key for backup01 will be in the system keyring.
    # The public key for backup03 will be imported from :keys.
    e.recipients = [
      # backup01 (short keyid)
      '16325C61',
      # backup03 (email)
      'backup03@foo.com'
    ]
  end
  store_with Local
end

Backup::Model.new(:encryptor_gpg_both_no_asymmetric, 'test_label') do
  archive :test_archive, &SpecLive::ARCHIVE_JOB
  encrypt_with GPG do |e|
    e.mode = :both
    e.passphrase = 'a secret'

    # valid entry for backup04, but this is not one of the recipients
    e.keys = {
      'backup04@foo.com' => SpecLive::GPGKeys[:backup04][:public]
    }

    # no keys will be found for these,
    # so only symmetric encryption will be possible for this backup
    e.recipients = [
      # backup01 (short keyid)
      '16325C61',
      # backup03 (email)
      'backup03@foo.com'
    ]
  end
  store_with Local
end
