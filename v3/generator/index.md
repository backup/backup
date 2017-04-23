---
layout: main
title: Generator
---

Generator
=========

The Backup generator is a very useful little tool to help you set up backups faster.

To bring up the `help` screen, run the following command:

    $ backup help generate:model

It'll display something like this:

    Usage:
      backup generate:model -t, --trigger=TRIGGER

    Options:
      -t, --trigger=TRIGGER  
          [--config-path=CONFIG_PATH]  # Path to your Backup configuration directory
          [--databases=DATABASES]      # (mongodb, mysql, postgresql, redis, riak)
          [--storages=STORAGES]        # (cloud_files, dropbox, ftp, local, rsync, s3, scp, sftp)
          [--syncers=SYNCERS]          # (cloud_files, rsync_local, rsync_pull, rsync_push, s3)
          [--encryptors=ENCRYPTORS]    # (gpg, openssl)
          [--compressors=COMPRESSORS]  # (bzip2, custom, gzip, lzma, pbzip2)
          [--notifiers=NOTIFIERS]      # (campfire, hipchat, http_post, mail, nagios, prowl, pushover, twitter)
          [--archives]  
          [--splitter]                 # use `--no-splitter` to disable
                                       # Default: true

The options is what makes setting up a Backup configuration file a breeze.

Example
-------

Say you have two databases, a [MongoDB][database-mongodb] and a [PostgreSQL][database-postgresql] database. You want to
backup these two databases and compress them with Gzip. You then want to package them up, encrypt them with
[GPG][encryptor-gpg], and store the backup to [Amazon S3][storage-s3]. Additionally, you have around 50GB of
"user-uploaded-content" in `/var/apps/my_app/public/uploads` you would like to [keep a mirror][syncer-s3] of on Amazon
S3. And finally, you want to be notified by email if there are any problems.

To get up and running quickly, issue the following command:

    $ backup generate:model --trigger my_backup \
        --databases="mongodb, postgresql" --storages="s3" --syncers="s3" \
        --encryptors="gpg" --compressors="gzip" --notifiers="mail"

This will create a new file: `~/Backup/models/my_backup.rb` (the default location), and the file will look like this:

```rb
##
# Backup Generated: my_backup
# Once configured, you can run the backup with the following command:
#
# $ backup perform -t my_backup [-c <path_to_configuration_file>]
#
Model.new(:my_backup, 'Description for my_backup') do
  ##
  # Split [Splitter]
  #
  # Split the backup file in to chunks of 250 megabytes
  # if the backup file size exceeds 250 megabytes
  #
  split_into_chunks_of 250

  ##
  # MongoDB [Database]
  #
  database MongoDB do |db|
    db.name               = "my_database_name"
    db.username           = "my_username"
    db.password           = "my_password"
    db.host               = "localhost"
    db.port               = 5432
    db.ipv6               = false
    db.only_collections   = ["only", "these", "collections"]
    db.additional_options = []
    db.lock               = false
    db.oplog              = false
  end

  ##
  # PostgreSQL [Database]
  #
  database PostgreSQL do |db|
    # To dump all databases, set `db.name = :all` (or leave blank)
    db.name               = "my_database_name"
    db.username           = "my_username"
    db.password           = "my_password"
    db.host               = "localhost"
    db.port               = 5432
    db.socket             = "/tmp/pg.sock"
    # When dumping all databases, `skip_tables` and `only_tables` are ignored.
    db.skip_tables        = ["skip", "these", "tables"]
    db.only_tables        = ["only", "these", "tables"]
    db.additional_options = ["-xc", "-E=utf8"]
  end

  ##
  # Amazon Simple Storage Service [Storage]
  #
  # See the documentation on the Wiki for details.
  # https://github.com/meskyanichi/backup/wiki/Storages
  store_with S3 do |s3|
    # AWS Credentials
    s3.access_key_id     = "my_access_key_id"
    s3.secret_access_key = "my_secret_access_key"
    # Or, to use a IAM Profile:
    # s3.use_iam_profile = true

    s3.region            = "us-east-1"
    s3.bucket            = "bucket-name"
    s3.path              = "path/to/backups"
  end

  ##
  # Amazon S3 [Syncer]
  #
  # See the documentation on the Wiki for details.
  # https://github.com/meskyanichi/backup/wiki/Syncers
  sync_with Cloud::S3 do |s3|
    # AWS Credentials
    s3.access_key_id     = "my_access_key_id"
    s3.secret_access_key = "my_secret_access_key"
    # Or, to use a IAM Profile:
    # s3.use_iam_profile = true

    s3.bucket            = "my-bucket"
    s3.region            = "us-east-1"
    s3.path              = "/backups"
    s3.mirror            = true
    s3.thread_count      = 10

    s3.directories do |directory|
      directory.add "/path/to/directory/to/sync"
      directory.add "/path/to/other/directory/to/sync"

      # Exclude files/folders from the sync.
      # The pattern may be a shell glob pattern (see `File.fnmatch`) or a Regexp.
      # All patterns will be applied when traversing each added directory.
      directory.exclude '**/*~'
      directory.exclude /\/tmp$/
    end
  end

  ##
  # GPG [Encryptor]
  #
  # Setting up #keys, as well as #gpg_homedir and #gpg_config,
  # would be best set in config.rb using Encryptor::GPG.defaults
  #
  encrypt_with GPG do |encryption|
    # Setup public keys for #recipients
    encryption.keys = {}
    encryption.keys['user@domain.com'] = <<-KEY
      -----BEGIN PGP PUBLIC KEY BLOCK-----
      Version: GnuPG v1.4.11 (Darwin)

          <Your GPG Public Key Here>
      -----END PGP PUBLIC KEY BLOCK-----
    KEY

    # Specify mode (:asymmetric, :symmetric or :both)
    encryption.mode = :both # defaults to :asymmetric

    # Specify recipients from #keys (for :asymmetric encryption)
    encryption.recipients = ['user@domain.com']

    # Specify passphrase or passphrase_file (for :symmetric encryption)
    encryption.passphrase = 'a secret'
    # encryption.passphrase_file = '~/backup_passphrase'
  end

  ##
  # Gzip [Compressor]
  #
  compress_with Gzip

  ##
  # Mail [Notifier]
  #
  # The default delivery method for Mail Notifiers is 'SMTP'.
  # See the Wiki for other delivery options.
  # https://github.com/meskyanichi/backup/wiki/Notifiers
  #
  notify_by Mail do |mail|
    mail.on_success           = true
    mail.on_warning           = true
    mail.on_failure           = true

    mail.from                 = "sender@email.com"
    mail.to                   = "receiver@email.com"
    mail.address              = "smtp.gmail.com"
    mail.port                 = 587
    mail.domain               = "your.host.name"
    mail.user_name            = "sender@email.com"
    mail.password             = "my_password"
    mail.authentication       = "plain"
    mail.encryption           = :starttls
  end

end
```

Just omit what you don't need, and change what you do need and you're done.

**Note:** If you want to change the path where the model file will be generated, use the `--config-path` option
to specify the path to the directory where Backup's main configuration file is located. So, if you have your main
configuration file in `/path/to/config.rb`, then you would generate your models using:

    $ backup generate:model --config-path='/path/to/' --trigger (etc...)


Main Configuration File
-----------------------

Generating the model above will also create the main Backup configuration file: `~/Backup/config.rb`

This is the first file Backup will load when performing your backup job. This is where you will setup any global
configuration and component defaults. After which, it will load all of your backup model files.


``` rb
##
# Backup
# Generated Main Config Template
#
# For more information:
#
# View the Git repository at https://github.com/meskyanichi/backup
# View the Wiki/Documentation at https://github.com/meskyanichi/backup/wiki
# View the issue log at https://github.com/meskyanichi/backup/issues

##
# Utilities
#
# If you need to use a utility other than the one Backup detects,
# or a utility can not be found in your $PATH.
#
#   Utilities.configure do
#     tar       '/usr/bin/gnutar'
#     redis_cli '/opt/redis/redis-cli'
#   end

##
# Logging
#
# Logging options may be set on the command line, but certain settings
# may only be configured here.
#
#   Logger.configure do
#     console.quiet     = true            # Same as command line: --quiet
#     logfile.max_bytes = 2_000_000       # Default: 500_000
#     syslog.enabled    = true            # Same as command line: --syslog
#     syslog.ident      = 'my_app_backup' # Default: 'backup'
#   end
#
# Command line options will override those set here.
# For example, the following would override the example settings above
# to disable syslog and enable console output.
#   backup perform --trigger my_backup --no-syslog --no-quiet

##
# Component Defaults
#
# Set default options to be applied to components in all models.
# Options set within a model will override those set here.
#
#   Storage::S3.defaults do |s3|
#     s3.access_key_id     = "my_access_key_id"
#     s3.secret_access_key = "my_secret_access_key"
#   end
#
#   Notifier::Mail.defaults do |mail|
#     mail.from                 = 'sender@email.com'
#     mail.to                   = 'receiver@email.com'
#     mail.address              = 'smtp.gmail.com'
#     mail.port                 = 587
#     mail.domain               = 'your.host.name'
#     mail.user_name            = 'sender@email.com'
#     mail.password             = 'my_password'
#     mail.authentication       = 'plain'
#     mail.encryption           = :starttls
#   end

##
# Preconfigured Models
#
# Create custom models with preconfigured components.
# Components added within the model definition will
# +add to+ the preconfigured components.
#
#   preconfigure 'MyModel' do
#     archive :user_pictures do |archive|
#       archive.add '~/pictures'
#     end
#
#     notify_by Mail do |mail|
#       mail.to = 'admin@email.com'
#     end
#   end
#
#   MyModel.new(:john_smith, 'John Smith Backup') do
#     archive :user_music do |archive|
#       archive.add '~/music'
#     end
#
#     notify_by Mail do |mail|
#       mail.to = 'john.smith@email.com'
#     end
#   end


# * * * * * * * * * * * * * * * * * * * *
#        Do Not Edit Below Here.
# All Configuration Should Be Made Above.

##
# Load all models from the models directory.
Dir[File.join(File.dirname(Config.config_file), "models", "*.rb")].each do |model|
  instance_eval(File.read(model))
end
```

For more information on the `Utilities` configuration, see the [Utilities][utilities] page.  
For more information on the `Logger` configuration, see the [Logging][logging] page.

By default, Backup will look for this file in `~/Backup/config.rb`. If you want to place your configuration files in a
different location, use the `--config_file` option:

    $ backup perform --trigger my_backup --config_file '/path/to/config.rb'

If you relocate this file, be sure to move the `models` directory as well.

If you need to re-generate only this main configuration file, you can do so using:

    $ backup generate:config


{% include markdown_links %}
