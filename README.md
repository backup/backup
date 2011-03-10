Backup 3
========

Backup is a RubyGem (for UNIX-like operating systems: Linux, Mac OSX) that allows you to configure and perform backups in a simple manner using an elegant Ruby DSL. It supports various various databases (MySQL, PostgreSQL, MongoDB and Redis), it supports various storage locations (Amazon S3, Rackspace Cloud Files, Dropbox, any remote server through FTP, SFTP, SCP and RSync), it can archive files and folders, it can cycle backups, it can do incremental backups, it can compress backups, it can encrypt backups (OpenSSL or GPG), it can notify you about successful and/or failed backups. It is very extensible and easy to add new functionality to. It's easy to use.

Author
------

Michael van Rooijen ( [@meskyanichi](http://twitter.com/#!/meskyanichi) )

Drop me a message for any questions, suggestions, requests, bugs or submit them to the [issue log](https://github.com/meskyanichi/backup/issues).

Installation
------------

To get the latest stable version

    gem install backup

To get the latest *build* of the latest stable version

    gem install backup --pre

Builds **aim** to be stable, but cannot guarantee it. Builds tend to be released a lot more frequent than the stable versions. So if you want to live on the edge and want the latest improvements, install the build gems.

You can view the list of released versions over at [RubyGems.org (Backup)](https://rubygems.org/gems/backup/versions)


What Backup 3 currently supports
================================

**Below you find a summary of what the Backup gem currently supports. Each of the items below is more or less isolated from each other, meaning that adding new databases, storage locations, compressors, encryptors, notifiers, and such is relatively easy to do.**

Database Support
----------------

- MySQL
- PostgreSQL
- MongoDB
- Redis

[Database Wiki Page](https://github.com/meskyanichi/backup/wiki/Databases)

Filesystem Support
------------------

- Files
- Folders

[Archive Wiki Page](https://github.com/meskyanichi/backup/wiki/Archives)

Storage Locations
-----------------

- Amazon Simple Storage Service (S3)
- Rackspace Cloud Files (Mosso)
- Dropbox
- Remote Servers *(Available Protocols: FTP, SFTP, SCP and RSync)*

[Storage Wiki Page](https://github.com/meskyanichi/backup/wiki/Storages)

Storage Features
----------------

- Backup Cycling, applies to:
  - Amazon Simple Storage Service (S3)
  - Rackspace Cloud Files (Mosso)
  - Dropbox
  - Remote Servers *(Only Protocols: FTP, SFTP, SCP)*
- Incremental Backups, applies to:
  - Remote Servers *(Only Protocols: RSync)*

[Storage Wiki Page](https://github.com/meskyanichi/backup/wiki/Storages)

Compressors
-----------

- Gzip

[Compressors Wiki Page](https://github.com/meskyanichi/backup/wiki/Compressors)

Encryptors
----------

- OpenSSL
- GPG

[Encryptors Wiki Page](https://github.com/meskyanichi/backup/wiki/Encryptors)

Notifiers
---------

- Mail

[Notifiers Wiki Page](https://github.com/meskyanichi/backup/wiki/Notifiers)

Supported Ruby versions (Tested with RSpec)
-------------------------------------------

- Ruby 1.9.2
- Ruby 1.8.7
- Ruby Enterprise Edition 1.8.7

Environments
------------

Backup **3** runs in **UNIX**-based operating systems: Linux, Mac OSX, etc. It does **NOT** run on the Windows operating system, and there are currently no plans to support it.

Compatibility
-------------

Backup **3** is **NOT** backwards compatible with Backup **2**. The command line interface has changed. The DSL has changed. And a lot more has changed. All for the better.


A sample "Backup" configuration file
====================================

Below you see a sample configuration file you could create for Backup 3. Just read through it slowly and I'm quite sure you will already know what's going to happen before I explain it to you. **(see explanation after the example)**

    Backup::Model.new(:sample_backup, 'A sample backup configuration') do

      database MySQL do |database|
        database.name               = 'my_sample_mysql_db'
        database.username           = 'my_username'
        database.password           = 'my_password'
        database.skip_tables        = ['logs']
        database.additional_options = ['--single-transaction', '--quick']
      end

      database MongoDB do |database|
        database.name             = 'my_sample_mongo_db'
        database.only_collections = ['users', 'events', 'posts']
      end

      archive :user_avatars do |archive|
        archive.add '/var/apps/my_sample_app/public/avatars'
      end

      archive :logs do |archive|
        archive.add '/var/apps/my_sample_app/logs/production.log'
        archive.add '/var/apps/my_sample_app/logs/newrelic_agent.log'
        archive.add '/var/apps/my_sample_app/logs/other.log'
      end

      encrypt_with OpenSSL do |encryption|
        encryption.password = 'my_secret_password'
      end

      compress_with Gzip do |compression|
        compression.best = true
      end

      store_with S3 do |s3|
        s3.access_key_id      = 'my_access_key_id'
        s3.secret_access_key  = 'my_secret_access_key'
        s3.region             = 'us-east-1'
        s3.bucket             = 'my_bucket/backups'
        s3.keep               = 20
      end

      store_with RSync do |server|
        server.username = 'my_username'
        server.password = 'my_password'
        server.ip       = '123.45.678.90'
        server.path     = '~/backups/'
      end

      notify_by Mail do |mail|
        mail.on_success = false
        mail.on_failure = true
      end
    end

### Explanation for the above example

First it dumps all the tables inside the MySQL database "my_sample_mysql_db", except for the "logs" table. It also dumps the MongoDB database "my_sample_mongo_db", but only the collections "users", "events" and "posts". After that it'll create a "user_avatars.tar" archive with all the uploaded avatars of the users. After that it'll create a "logs.tar" archive with the "production.log", "newrelic_agent.log" and "other.log" logs. After that it'll encrypt the whole backup file (everything included: databases, archives) using "OpenSSL". Now the Backup can only be extracted when you know the password to decrypt it ("my_secret_password" in this case). After that it'll compress the backup file using Gzip (with the mode set to "best", rather than "fast" for best compression). Then it'll store the backup file to Amazon S3 in to 'my_bucket/backups'. Next it'll also transfer a copy of the backup file to a remote server using the RSync protocol, and it'll be stored in to the "$HOME/backups/" path on this server. Finally, it'll notify me by email if the backup raises an error/exception during the process indicating that something went wrong. (When setting `mail.on_success = true` it'll also notify you of every successful backup)

### Things to note

The __keep__ option I passed in to the S3 storage location enables "Backup Cycling". In this case, after the 21st backup file gets pushed, it'll exceed the 20 backup limit, and remove the oldest backup from the S3 bucket.

The __RSync__ protocol doesn't utilize the __keep__ option. RSync is used to do incremental backups, and only stores a single file on your remote server, which gets incrementally updated with each run. For example, if everything you dump ends up to be about 2000MB, the first time, you'll be transferring the full 2000MB. If by the time the next backup run starts this dump has increased to 2100MB, it'll calculate the difference between the source and destination file and only transfer the remaining 100MB, rather than the full 2100MB. (Note: To reduce bandwidth as much as possible with RSync, ensure you don't use compression or encryption, otherwise RSync isn't able to calculate the difference very well and bandwidth usage greatly increases.)

The __Mail__ notifier. I have not provided the SMTP options to use my Gmail account to notify myself when exceptions are raised during the process. So this won't work, check out the wiki on how to configure this. I left it out in this example.

### And that's it!

So as you can see the DSL is straightforward and should be simple to understand and extend to your needs. You can have as many databases, archives, storage locations, compressors, encryptors and notifiers inside the above example as you need and it'll bundle all of it up in a nice packaged archive and transfer it to every specified location (as redundant as you like).

### Running the example

Remember the `Backup::Model.new(:sample_backup, 'A sample backup configuration') do`?
The `:sample_backup` is called the "id", or "trigger". This is used to identify the backup procedure/file and initialize it.

    backup perform -t sample_backup

That's it.

### Automatic backups

Since it's a simple command line utility, just write a cron to invoke it whenever you want. I recommend you use the [Whenever Gem](https://github.com/javan/whenever) to manage your cron tasks. It'll enable you to write such elegant automatic backup syntax in Ruby:

    every 6.hours do
      command "backup perform -t sample_backup"
    end


Documentation
-------------

See the [Wiki Pages](https://github.com/meskyanichi/backup/wiki). The subjects labeled **without** the "Backup 2)"-prefix are meant for Backup 3 users.


Suggestions, Bugs, Requests, Questions
--------------------------------------

View the [issue log](https://github.com/meskyanichi/backup/issues) and post them there.


Want to contribute?
-------------------

- Fork/Clone the **develop** branch
- Write RSpec tests, and test against:
  - Ruby 1.9.2
  - Ruby 1.8.7
  - Ruby Enterprise Edition 1.8.7
- Try to keep the overall *structure / design* of the gem the same

I can't guarantee I'll pull every pull request. Also, I may accept your pull request and drastically change parts to improve readability/maintainability. Feel free to discuss about improvements, new functionality/features in the [issue log](https://github.com/meskyanichi/backup/issues) before contributing if you need/want more information.


Backup 2 - Issues, Wiki, Source, Gems
=====================================

I won't actively support Backup 2 anymore. The source will remain on [a separate branch](https://github.com/meskyanichi/backup/tree/backup-2). [The Issues](https://github.com/meskyanichi/backup/issues) that belong to Backup 2 have been tagged with a black label "Backup 2". The Backup 2 specific [Wiki pages](https://github.com/meskyanichi/backup/wiki) have been prefixed with "Backup 2) <Article>". [The Backup 2 Gems](http://rubygems.org/gems/backup) will always remain so you can still use Backup 2. I might still accept pull requests, but would highly encourage anyone to [move to __Backup 3__ once it's here](https://github.com/meskyanichi/backup).