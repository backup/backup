Backup
======

Backup is a system utility for Linux and Mac OS X, distributed as a RubyGem, that allows you to easily perform backup
operations. It provides an elegant DSL in Ruby for _modeling_ your backups. Backup has built-in support for various
databases, storage protocols/services, syncers, compressors, encryptors and notifiers which you can mix and match. It
was built with modularity, extensibility and simplicity in mind.

## Installation

To install the latest version, run:

    $ [sudo] gem install backup

_Do not add `gem backup` to an application's `Gemfile`_

See [Installation](https://github.com/meskyanichi/backup/wiki/Installation) for more information about installing and
updating your installation of Backup.

See [Release Notes](https://github.com/meskyanichi/backup/wiki/Release-Notes) for changes in the latest version.

Backup supports Ruby versions 1.8.7, 1.9.2, 1.9.3 and 2.0.0.

## Overview

Backup allows you to _model_ your backup jobs using a Ruby DSL:

```rb
Backup::Model.new(:my_backup, 'Description for my_backup') do
  # ... components here ...
end
```

The `:my_backup` symbol is the model's `trigger` and used to perform the job:

    $ backup perform --trigger my_backup

Backup's _components_ are added to the backup _model_ to define the actions to be performed.  
All of Backup's components are fully documented in the [Backup Wiki](https://github.com/meskyanichi/backup/wiki).  
The following is brief overview of the components Backup provides:

### Archives and Databases

[Archives](https://github.com/meskyanichi/backup/wiki/Archives) create basic `tar` archives. Both **GNU** and **BSD**
`tar` are supported.  
[Databases](https://github.com/meskyanichi/backup/wiki/Databases) create backups of one of the following supported databases:

- MySQL
- PostgreSQL
- MongoDB
- Redis
- Riak

Any number of Archives and Databases may be defined within a backup _model_.

### Compressors and Encryptors

Adding a [Compressor](https://github.com/meskyanichi/backup/wiki/Compressors) to your backup will compress all the
Archives and Database backups within your final archive package.  
`Gzip`, `Bzip2` and other similar compressors are supported.

Adding a [Encryptor](https://github.com/meskyanichi/backup/wiki/Encryptors) allows you to encrypt your final backup package.  
Both `OpenSSL` and `GPG` are supported.

Your final backup _package_ might look something like this:

```text
$ gpg --decrypt my_backup.tar.gpg --outfile my_backup.tar
$ tar -tvf my_backup.tar
  my_backup/
  my_backup/archives/
  my_backup/archives/user_avatars.tar.gz
  my_backup/archives/log_files.tar.gz
  my_backup/databases/
  my_backup/databases/PostgreSQL.sql.gz
  my_backup/databases/Redis.rdb.gz
```

### Storages

Once your final backup package is ready, you can use any number of the following
[Storages](https://github.com/meskyanichi/backup/wiki/Storages) to store it:

- Amazon Simple Storage Service (S3)
- Rackspace Cloud Files (Mosso)
- Ninefold Cloud Storage
- Dropbox Web Service
- Remote Servers _(Available Protocols: FTP, SFTP, SCP and RSync)_
- Local Storage _(including network mounted locations)_

All of the above Storages _(except RSync)_ support:

- [Cycling](https://github.com/meskyanichi/backup/wiki/Cycling) to keep and rotate multiple copies
of your stored backups.

- [Splitter](https://github.com/meskyanichi/backup/wiki/Splitter) to break up a large
backup package into smaller files.

When using the RSync Storage, once a full backup has been stored, subsequent backups only need to
transmit the changed portions of the final archive to bring the remote copy up-to-date.

### Syncers

[Syncers](https://github.com/meskyanichi/backup/wiki/Syncers) are processed after your final backup archive has been
stored and allow you to perform file synchronization.

Backup includes two types of Syncers:

- `RSync`: Used to sync files locally, local-to-remote (`Push`), or remote-to-local (`Pull`).  
- `Cloud`: Used to sync files to remote storage services like Amazon S3 and Rackspace.

A backup _model_ may contain _only_ Syncers as well.

### Notifiers

[Notifiers](https://github.com/meskyanichi/backup/wiki/Notifiers) are used to send notifications upon successful and/or
failed completion of your backup _model_.

Supported notification services include:

- Email _(SMTP, Sendmail, Exim and File delivery)_
- Twitter
- Campfire
- Presently
- Prowl
- Hipchat
- Pushover
- POST Request


## Generators

Backup makes it easy to setup new backup _model_ files with it's [Generator](https://github.com/meskyanichi/backup/wiki/Generator) command.  

```
$ backup generate:model -t my_backup --archives --databases=postgresql,redis --compressors=gzip \
    --encryptors=gpg --storages=sftp,s3 --notifiers=mail,twitter
```

Simply generate a new _model_ using the options you need, then update the configuration for each component using the
[Wiki](https://github.com/meskyanichi/backup/wiki) documentation.

The following is an example of a what this Backup _model_ might look like:

```rb
Backup::Model.new(:my_backup, 'Description for my_backup') do
  split_into_chunks_of 250

  archive :user_avatars do |archive|
    archive.add '/var/apps/my_sample_app/public/avatars'
  end

  archive :log_files do |archive|
    archive.add     '/var/apps/my_sample_app/logs'
    archive.exclude '/var/apps/my_sample_app/logs/exclude-this.log'
  end

  database PostgreSQL do |db|
    db.name               = "pg_db_name"
    db.username           = "username"
    db.password           = "password"
  end

  database Redis do |db|
    db.name               = "redis_db_name"
    db.path               = "/usr/local/var/db/redis"
    db.password           = "password"
    db.invoke_save        = true
  end

  compress_with Gzip

  encrypt_with GPG do |encryption|
    encryption.mode = :symmetric
    encryption.passphrase = 'my_password'
  end

  store_with SFTP do |server|
    server.username   = "my_username"
    server.password   = "my_password"
    server.ip         = "123.45.678.90"
    server.port       = 22
    server.path       = "~/backups/"
    server.keep       = 5
  end

  store_with S3 do |s3|
    s3.access_key_id     = "my_access_key_id"
    s3.secret_access_key = "my_secret_access_key"
    s3.region            = "us-east-1"
    s3.bucket            = "bucket-name"
    s3.path              = "/path/to/my/backups"
    s3.keep              = 10
  end

  notify_by Mail do |mail|
    mail.on_success           = false

    mail.from                 = "sender@email.com"
    mail.to                   = "receiver@email.com"
    mail.address              = "smtp.gmail.com"
    mail.port                 = 587
    mail.user_name            = "sender@email.com"
    mail.password             = "my_password"
    mail.authentication       = "plain"
    mail.encryption           = :starttls
  end

  notify_by Twitter do |tweet|
    tweet.consumer_key       = "my_consumer_key"
    tweet.consumer_secret    = "my_consumer_secret"
    tweet.oauth_token        = "my_oauth_token"
    tweet.oauth_token_secret = "my_oauth_token_secret"
  end
end
```

The [Getting Started](https://github.com/meskyanichi/backup/wiki/Getting-Started) page provides a simple
walk-through to familiarize you with setting up, configuring and running a backup job.

## Suggestions, Issues, etc...

If you have any suggestions or problems, please submit an Issue or Pull Request using Backup's
[Issue Log](https://github.com/meskyanichi/backup/issues).

If you find any errors or omissions in Backup's documentation [Wiki](https://github.com/meskyanichi/backup/wiki),
please feel free to edit it!

Backup has seen many improvements over the years thanks to it's
[Contributors](https://github.com/meskyanichi/backup/contributors), as well as those who have help discuss issues and
improve the documentation, and looks forward to continuing to provide users with a reliable backup solution.

**Copyright (c) 2009-2013 [Michael van Rooijen](http://michaelvanrooijen.com/) ( [@meskyanichi](http://twitter.com/#!/meskyanichi) )**  
Released under the **MIT** [License](LICENSE.md).
