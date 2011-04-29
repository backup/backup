Backup 3
========

Backup is a RubyGem (for UNIX-like operating systems: Linux, Mac OSX) that allows you to configure and perform backups in a simple manner using an elegant Ruby DSL. It supports various databases (MySQL, PostgreSQL, MongoDB and Redis), it supports various storage locations (Amazon S3, Rackspace Cloud Files, Dropbox, any remote server through FTP, SFTP, SCP and RSync), it provide Syncers (RSync, S3) for efficient backups, it can archive files and directories, it can cycle backups, it can do incremental backups, it can compress backups, it can encrypt backups (OpenSSL or GPG), it can notify you about successful and/or failed backups (Email, Twitter or Campfire). It is very extensible and easy to add new functionality to. It's easy to use.

Author
------

**Michael van Rooijen ( [@meskyanichi](http://twitter.com/#!/meskyanichi) )**

Drop me a message for any questions, suggestions, requests, bugs or submit them to the [issue log](https://github.com/meskyanichi/backup/issues).

Installation
------------

To get the latest stable version

    gem install backup

You can view the list of released versions over at [RubyGems.org (Backup)](https://rubygems.org/gems/backup/versions)

Getting Started
---------------

I recommend you read this README first, and refer to the [Wiki pages](https://github.com/meskyanichi/backup/wiki) afterwards. There's also a [Getting Started wiki page](https://github.com/meskyanichi/backup/wiki/Getting-Started).

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
- Directories

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

Syncers
-------

- RSync
- Amazon Simple Storage Service (S3)

[Syncer Wiki Page](https://github.com/meskyanichi/backup/wiki/Syncers)

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
- Twitter
- Campfire

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

      sync_with S3 do |s3|
        s3.access_key_id     = "my_access_key_id"
        s3.secret_access_key = "my_secret_access_key"
        s3.bucket            = "my-bucket"
        s3.path              = "/backups"
        s3.mirror            = true

        s3.directories do |directory|
          directory.add "/var/apps/my_app/public/videos"
          directory.add "/var/apps/my_app/public/music"
        end
      end

      notify_by Mail do |mail|
        mail.on_success = false
        mail.on_failure = true
      end

      notify_by Twitter do |tweet|
        tweet.on_success = true
        tweet.on_failure = true
      end

    end

### Explanation for the above example

First it dumps all the tables inside the MySQL database "my_sample_mysql_db", except for the "logs" table. It also dumps the MongoDB database "my_sample_mongo_db", but only the collections "users", "events" and "posts". After that it'll create a "user_avatars.tar" archive with all the uploaded avatars of the users. After that it'll create a "logs.tar" archive with the "production.log", "newrelic_agent.log" and "other.log" logs. After that it'll compress the backup file using Gzip (with the mode set to "best", rather than "fast" for best compression). After that it'll encrypt the whole backup file (everything included: databases, archives) using "OpenSSL". Now the Backup can only be extracted when you know the password to decrypt it ("my_secret_password" in this case). Then it'll store the backup file to Amazon S3 in to 'my_bucket/backups'. Next, we're going to use the S3 Syncer to create a mirror of the `/var/apps/my_app/public/videos` and `/var/apps/my_app/public/music` directories on Amazon S3. (This will not package, compress, encrypt - but will directly sync the specified directories "as is" to your S3 bucket). Finally, it'll notify me by email if the backup raises an error/exception during the process, indicating that something went wrong. However, it does not notify me by email when successful backups occur because I set `mail.on_success` to `false`. It'll also notify me by Twitter when failed backups occur, but also when successful ones occur because I set the `tweet.on_success` to `true`.

### Things to note

The __keep__ option I passed in to the S3 storage location enables "Backup Cycling". In this case, after the 21st backup file gets pushed, it'll exceed the 20 backup limit, and remove the oldest backup from the S3 bucket.

The __S3__ Syncer ( `sync_with` ) is a different kind of __Storage__ method. As mentioned above, it does not follow the same procedure as the __Storage__ ( `store_with` ) method. A Storage method stores the final result of a copied/organized/packaged/compressed/encrypted file to the desired remote location. A Syncer directly syncs the specified directories and **completely bypasses** the copy/organize/package/compress/encrypt process. This is especially good for backing up directories containing gigabytes of data, such as images, music, videos, and similar large formats. Also, rather than transferring the whole directory every time, it'll only transfer files in all these directories that have been modified or added, thus, saving huge amounts of bandwidth, cpu load and time. You're also not bound to the 5GB per file restriction like the **Storage** method, unless you actually have files in these directories that are >= 5GB, which often is unlikely. Even if the whole directory (and sub-directories) are > 5GB (split over multiple files), it shouldn't be a problem as long as you don't have any *single* file that is 5GB in size. Also, in the above example you see `s3.mirror = true`, this tells the S3 Syncer to keep a "mirror" of the local directories in the S3 bucket. This means that if you delete a file locally, the next time it syncs, it'll also delete the file from the S3 bucket, keeping the local filesystem 1:1 with the S3 bucket.

The __Mail__ notifier. I have not provided the SMTP options to use my Gmail account to notify myself when exceptions are raised during the process. So this won't work, check out the wiki on how to configure this. I left it out in this example.

The __Twitter__ notifier. You will require your consumer and oauth credentials, which I have also left out of this example.

MongoDB backup utility (mongodump) by default does not fsync & lock the database, opening a possibility for inconsistent data dump. This is addressed by setting safe = true which causes mongodump to be wrapped with lock&fsync calls (with a lock takedown after the dump). Please check the Wiki on this subject and remember this is a very fresh feature, needing some more real-world testing. Disabled at default.

Check out the Wiki for more information on all the above subjects.

### And that's it!

So as you can see the DSL is straightforward and should be simple to understand and extend to your needs. You can have as many databases, archives, storage locations, syncers, compressors, encryptors and notifiers inside the above example as you need and it'll bundle all of it up in a nice packaged archive and transfer it to every specified location (as redundant as you like).

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

Contributors
------------

<table>
  <tr>
    <th>Contributor</th>
    <th>Contribution</th>
  </tr>
  <tr>
    <td><a href="https://github.com/asanghi" target="_blank">Aditya Sanghi ( asanghi )</a></td>
    <td>Twitter Notifier, Dropbox Timeout Configuration</td>
  </tr>
  <tr>
    <td><a href="https://github.com/phlipper" target="_blank">Phil Cohen ( phlipper )</a></td>
    <td>Exclude Option for Archives</td>
  </tr>
  <tr>
    <td><a href="https://github.com/arunagw" target="_blank">Arun Agrawal ( arunagw )</a></td>
    <td>Campfire notifier</td>
  </tr>
  <tr>
    <td><a href="https://github.com/szimmermann" target="_blank">Stefan Zimmermann ( szimmermann )</a></td>
    <td>Enabling package/archive (tar utility) support for more Linux distro's (FreeBSD, etc)</td>
  </tr>
</table>

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