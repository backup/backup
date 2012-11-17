Backup
======

Backup is a RubyGem, written for Linux and Mac OSX, that allows you to easily perform backup operations on both your remote and local environments. It provides you with an elegant DSL in Ruby for modeling your backups. Backup has built-in support for various databases, storage protocols/services, syncers, compressors, encryptors and notifiers which you can mix and match. It was built with modularity, extensibility and simplicity in mind.

[![Build Status](https://secure.travis-ci.org/meskyanichi/backup.png)](http://travis-ci.org/meskyanichi/backup)
[![Still Maintained](http://stillmaintained.com/meskyanichi/backup.png)](http://stillmaintained.com/meskyanichi/backup)


### Author

**[Michael van Rooijen](http://michaelvanrooijen.com/) ( [@meskyanichi](http://twitter.com/#!/meskyanichi) )**

Drop me a message for any questions, suggestions, requests, bugs or submit them to the [issue log](https://github.com/meskyanichi/backup/issues).


### Installation

To get the latest stable version

    gem install backup

You can view the list of released versions over at [RubyGems.org (Backup)](https://rubygems.org/gems/backup/versions)


### Getting Started

I recommend you read this README first, and refer to the [wiki pages](https://github.com/meskyanichi/backup/wiki) afterwards. There's also a [Getting Started wiki page](https://github.com/meskyanichi/backup/wiki/Getting-Started).

What Backup 3 currently supports
--------------------------------

Below you find a list of components that Backup currently supports. If you'd like support for components other than the ones listed here, feel free to request them or to fork Backup and add them yourself. Backup is modular and easy to extend.

### Database Support

- MySQL
- PostgreSQL
- MongoDB
- Redis
- Riak

[Database Wiki Page](https://github.com/meskyanichi/backup/wiki/Databases)

### Filesystem Support

- Files
- Directories

[Archive Wiki Page](https://github.com/meskyanichi/backup/wiki/Archives)

### Storage Locations and Services

- Amazon Simple Storage Service (S3)
- Rackspace Cloud Files (Mosso)
- Ninefold Cloud Storage
- Dropbox Web Service
- Remote Servers *(Available Protocols: FTP, SFTP, SCP and RSync)*
- Local Storage

[Storage Wiki Page](https://github.com/meskyanichi/backup/wiki/Storages)

### Storage Features

- **Backup Cycling, applies to:**
  - Amazon Simple Storage Service (S3)
  - Rackspace Cloud Files (Mosso)
  - Ninefold Cloud Storage
  - Dropbox Web Service
  - Remote Servers *(Only Protocols: FTP, SFTP, SCP)*
  - Local Storage

[Cycling Wiki Page](https://github.com/meskyanichi/backup/wiki/Cycling)

- **Backup Splitting, applies to:**
  - Amazon Simple Storage Service (S3)
  - Rackspace Cloud Files (Mosso)
  - Ninefold Cloud Storage
  - Dropbox Web Service
  - Remote Servers *(Only Protocols: FTP, SFTP, SCP)*
  - Local Storage

[Splitter Wiki Page](https://github.com/meskyanichi/backup/wiki/Splitter)

- **Incremental Backups, applies to:**
  - Remote Servers *(Only Protocols: RSync)*

### Syncers

- RSync (Push, Pull and Local)
- Amazon S3
- Rackspce Cloud Files

[Syncer Wiki Page](https://github.com/meskyanichi/backup/wiki/Syncers)

### Compressors

- Gzip
- Bzip2
- Pbzip2
- Lzma

[Compressors Wiki Page](https://github.com/meskyanichi/backup/wiki/Compressors)

### Encryptors

- OpenSSL
- GPG

[Encryptors Wiki Page](https://github.com/meskyanichi/backup/wiki/Encryptors)

### Notifiers

- Mail
- Twitter
- Campfire
- Presently
- Prowl
- Hipchat
- Pushover

[Notifiers Wiki Page](https://github.com/meskyanichi/backup/wiki/Notifiers)

### Supported Ruby versions (Tested with RSpec)

- Ruby 1.9.3
- Ruby 1.9.2
- Ruby 1.8.7


A sample Backup configuration file
----------------------------------

This is a Backup configuration file. Check it out and read the explanation below.
Backup has a [great wiki](https://github.com/meskyanichi/backup/wiki) which explains each component of Backup in detail.

``` rb
Backup::Model.new(:sample_backup, 'A sample backup configuration') do

  split_into_chunks_of 4000

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
    archive.add     '/var/apps/my_sample_app/logs/production.log'
    archive.add     '/var/apps/my_sample_app/logs/newrelic_agent.log'
    archive.add     '/var/apps/my_sample_app/logs/other/'
    archive.exclude '/var/apps/my_sample_app/logs/other/exclude-this.log'
  end

  encrypt_with OpenSSL do |encryption|
    encryption.password = 'my_secret_password'
  end

  compress_with Gzip

  store_with SFTP, "Server A" do |server|
    server.username = 'my_username'
    server.password = 'secret'
    server.ip       = 'a.my-backup-server.com'
    server.port     = 22
    server.path     = '~/backups'
    server.keep     = 25
  end

  store_with SFTP, "Server B" do |server|
    server.username = 'my_username'
    server.password = 'secret'
    server.ip       = 'b.my-backup-server.com'
    server.port     = 22
    server.path     = '~/backups'
    server.keep     = 25
  end

  store_with S3 do |s3|
    s3.access_key_id      = 'my_access_key_id'
    s3.secret_access_key  = 'my_secret_access_key'
    s3.region             = 'us-east-1'
    s3.bucket             = 'my_bucket/backups'
    s3.keep               = 20
  end

  sync_with Cloud::S3 do |s3|
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
    mail.on_warning = true
    mail.on_failure = true
  end

  notify_by Twitter do |tweet|
    tweet.on_success = true
    tweet.on_warning = true
    tweet.on_failure = true
  end

end
```

### Brief explanation for the above example configuration

First, it will dump the two Databases (MySQL and MongoDB). The MySQL dump will be piped through the Gzip Compressor into
`sample_backup/databases/MySQL/my_sample_mysql_db.sql.gz`. The MongoDB dump will be dumped into
`sample_backup/databases/MongoDB/`, which will then be packaged into `sample_backup/databases/MongoDB-#####.tar.gz`
(`#####` will be a simple unique identifier, in case multiple dumps are performed.)
Next, it will create two _tar_ Archives (user\_avatars and logs). Each will be piped through the Gzip Compressor into
`sample_backup/archives/` as `user_archives.tar.gz` and `logs.tar.gz`.
Finally, the `sample_backup` directory will be packaged into an uncompressed _tar_ archive, which will be piped through
the OpenSSL Encryptor to encrypt this final package into `YYYY-MM-DD-hh-mm-ss.sample_backup.tar.enc`. This final
encrypted archive will then be transfered to your Amazon S3 account. If all goes well, and no exceptions are raised,
you'll be notified via the Twitter notifier that the backup succeeded. If any warnings were issued or there was an
exception raised during the backup process, then you'd receive an email in your inbox containing detailed exception
information, as well as receive a simple Twitter message that something went wrong.

Aside of S3, we have also defined two `SFTP` storage methods, and given them two unique identifiers `Server A` and
`Server B` to distinguish between the two. With these in place, a copy of the backup will now also be stored on two
separate servers: `a.my-backup-server.com` and `b.my-backup-server.com`.

As you can see, you can freely mix and match **archives**, **databases**, **compressors**, **encryptors**, **storages**
and **notifiers** for your backups. You could even specify 4 storage locations if you wanted: Amazon S3, Rackspace Cloud
Files, Ninefold and Dropbox, it'd then store your packaged backup to 4 separate locations for high redundancy.

Also, notice the `split_into_chunks_of 4000` at the top of the configuration. This tells Backup to split any backups
that exceed in 4000 MEGABYTES of size in to multiple smaller chunks. Assuming your backup file is 12000 MEGABYTES (12GB)
in size, then Backup will take the output which was piped from _tar_ into the OpenSSL Compressor and additionally pipe
that output through the _split_ utility, which will result in 3 chunks of 4000 MEGABYTES with additional file extensions
of `-aa`, `-ab` and `-ac`. These files will then be individually transfered. This is useful for when you are using
Amazon S3, Rackspace Cloud Files, or other 3rd party storage services which limit you to "5GB per file" uploads. So with
this, the backup file size is no longer a constraint.

Additionally we have also defined a **S3 Syncer** ( `sync_with Cloud::S3` ), which does not follow the above process of
archiving/compression/encryption, but instead will directly sync the whole `videos` and `music` folder structures from
your machine to your Amazon S3 account. (very efficient and cost-effective since it will only transfer files that were
added/changed. Additionally, since we flagged it to 'mirror', it'll also remove files from S3 that no longer exist). If
you simply wanted to sync to a separate backup server that you own, you could also use the RSync syncer for even more
efficient backups that only transfer the **bytes** of each file that changed.

There are more **archives**, **databases**, **compressors**, **encryptors**, **storages** and **notifiers** than
displayed in the example, all available components are listed at the top of this README, as well as in the
[Wiki](https://github.com/meskyanichi/backup/wiki) with more detailed information.

### Running the example

Notice the `Backup::Model.new(:sample_backup, 'A sample backup configuration') do` at the top of the above example. The
`:sample_backup` is called the **trigger**. This is used to identify the backup procedure/file and initialize it.

``` sh
backup perform -t [--trigger] sample_backup
```

Now it'll run the backup, it's as simple as that.

### Automatic backups

Since Backup is an easy-to-use command line utility, you should write a crontask to invoke it periodically. I recommend
using [Whenever](https://github.com/javan/whenever) to manage your crontab. It'll allow you to write to the crontab
using pure Ruby, and it provides an elegant DSL to do so. Here's an example:

``` rb
every 6.hours do
  command "backup perform --trigger sample_backup"
end
```

With this in place, run `whenever --update-crontab backup` to write the equivalent of the above Ruby syntax to the
crontab in cron-syntax. Cron will now invoke `backup perform --trigger sample_backup` every 6 hours. Check out the
Whenever project page for more information.

### Documentation

See the [Wiki Pages](https://github.com/meskyanichi/backup/wiki).


### Suggestions, Bugs, Requests, Questions

View the [issue log](https://github.com/meskyanichi/backup/issues) and post them there.

### Contributors

<table>
  <tr>
    <th>Contributor</th>
    <th>Contribution</th>
  </tr>
  <tr>
    <td><a href="https://github.com/burns" target="_blank"><b>Brian D. Burns ( burns )</b></a></td>
    <td><b>Core Contributor</b></td>
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
  <tr>
    <td><a href="https://github.com/trystant" target="_blank">Mark Nyon ( trystant )</a></td>
    <td>Helping discuss MongoDump Lock/FSync problem</td>
  </tr>
  <tr>
    <td><a href="https://github.com/imanel" target="_blank">Bernard Potocki ( imanel )</a></td>
    <td>Helping discuss MongoDump Lock/FSync problem + Submitting a patch</td>
  </tr>
  <tr>
    <td><a href="https://github.com/tomash" target="_blank">Tomasz Stachewicz ( tomash )</a></td>
    <td>Helping discuss MongoDump Lock/FSync problem + Submitting a patch</td>
  </tr>
  <tr>
    <td><a href="https://github.com/lapluviosilla" target="_blank">Paul Strong ( lapluviosilla )</a></td>
    <td>Helping discuss MongoDump Lock/FSync problem</td>
  </tr>
  <tr>
    <td><a href="https://github.com/rgnitz" target="_blank">Ryan ( rgnitz )</a></td>
    <td>Helping discuss MongoDump Lock/FSync problem</td>
  </tr>
  <tr>
    <td><a href="https://github.com/tsigo" target="_blank">Robert Speicher ( tsigo )</a></td>
    <td>Adding the --quiet [-q] feature to Backup to silence console logging</td>
  </tr>
  <tr>
    <td><a href="https://github.com/jwhitcraft" target="_blank">Jon Whitcraft ( jwhitcraft )</a></td>
    <td>Adding the ability to add additional options to the S3Syncer</td>
  </tr>
  <tr>
    <td><a href="https://github.com/bgarret" target="_blank">Benoit Garret ( bgarret )</a></td>
    <td>Presently notifier</td>
  </tr>
  <tr>
    <td><a href="https://github.com/lleirborras" target="_blank">Lleïr Borràs Metje ( lleirborras )</a></td>
    <td>Lzma Compressor</td>
  </tr>
  <tr>
    <td><a href="https://github.com/jof" target="_blank">Jonathan Lassoff ( jof )</a></td>
    <td>Bugfixes and more secure GPG storage</td>
  </tr>
  <tr>
    <td><a href="https://github.com/mikz" target="_blank">Michal Cichra ( mikz )</a></td>
    <td>Wildcard Triggers</td>
  </tr>
  <tr>
    <td><a href="https://github.com/trybeee" target="_blank">Dmitry Novotochinov ( trybeee )</a></td>
    <td>Dropbox Storage</td>
  </tr>
  <tr>
    <td><a href="https://github.com/Emerson" target="_blank">Emerson Lackey ( Emerson )</a></td>
    <td>Local RSync Storage</td>
  </tr>
  <tr>
    <td><a href="https://github.com/digilord" target="_blank">digilord</a></td>
    <td>OpenSSL Verify Mode for Mail Notifier</td>
  </tr>
  <tr>
    <td><a href="https://github.com/stemps" target="_blank">stemps</a></td>
    <td>FTP Passive Mode</td>
  </tr>
  <tr>
    <td><a href="https://github.com/dkowis" target="_blank">David Kowis ( dkowis )</a></td>
    <td>Fixed PostgreSQL Password issues</td>
  </tr>
  <tr>
    <td><a href="https://github.com/jotto" target="_blank">Jonathan Otto ( jotto )</a></td>
    <td>Allow for running PostgreSQL as another UNIX user</td>
  </tr>
  <tr>
    <td><a href="https://github.com/joaovitor" target="_blank">João Vitor ( joaovitor )</a></td>
    <td>Changed default PostgreSQL example options to appropriate ones</td>
  </tr>
  <tr>
    <td><a href="https://github.com/swissmanu" target="_blank">Manuel Alabor ( swissmanu )</a></td>
    <td>Prowl Notifier</td>
  </tr>
  <tr>
    <td><a href="https://github.com/josephcrim" target="_blank">Joseph Crim ( josephcrim )</a></td>
    <td>Riak Database, exit() suggestions</td>
  </tr>
  <tr>
    <td><a href="https://github.com/fearoffish" target="_blank">Jamie van Dyke ( fearoffish )</a></td>
    <td>POpen4 implementation</td>
  </tr>
  <tr>
    <td><a href="https://github.com/hmarr" target="_blank">Harry Marr ( hmarr )</a></td>
    <td>Auth URL for Rackspace Cloud Files Storage</td>
  </tr>
  <tr>
    <td><a href="https://github.com/manuelmeurer" target="_blank">Manuel Meurer ( manuelmeurer )</a></td>
    <td>Ensure the storage file (YAML dump) has content before reading it</td>
  </tr>
  <tr>
    <td><a href="https://github.com/jessedearing" target="_blank">Jesse Dearing ( jessedearing )</a></td>
    <td>Hipchat Notifier</td>
  </tr>
  <tr>
    <td><a href="https://github.com/szymonpk" target="_blank">Szymon ( szymonpk )</a></td>
    <td>Pbzip2 compressor</td>
  </tr>
  <tr>
    <td><a href="https://github.com/SteveNewson" target="_blank">Steve Newson ( SteveNewson )</a></td>
    <td>Pushover Notifier</td>
  </tr>
</table>


### Want to contribute?

- Fork the project
- Write RSpec tests, and test against:
  - Ruby 1.9.3
  - Ruby 1.9.2
  - Ruby 1.8.7
- Try to keep the overall *structure / design* of the gem the same

I can't guarantee I'll pull every pull request. Also, I may accept your pull request and drastically change parts to improve readability/maintainability. Feel free to discuss about improvements, new functionality/features in the [issue log](https://github.com/meskyanichi/backup/issues) before contributing if you need/want more information.


### Easily run tests against all three Ruby versions

Install [RVM](https://rvm.beginrescueend.com/) and use it to install Ruby 1.9.3, 1.9.2 and 1.8.7.

    rvm get latest && rvm reload
    rvm install 1.9.3 && rvm install 1.9.2 && rvm install 1.8.7

Once these are installed, go ahead and install all the necessary dependencies.

    cd backup
    rvm use 1.9.3 && gem install bundler && bundle install
    rvm use 1.9.2 && gem install bundler && bundle install
    rvm use 1.8.7 && gem install bundler && bundle install

The Backup gem uses [Guard](https://github.com/guard/guard) along with [Guard::RSpec](https://github.com/guard/guard-rspec) to quickly and easily test Backup's code against all four Rubies. If you've done the above, all you have to do is run:

    bundle exec guard

from Backup's root and that's it. It'll now test against all Ruby versions each time you adjust a file in the `lib` or `spec` directories.


### Or contribute by writing blogs/tutorials/use cases

- http://freelancing-gods.com/posts/backing_up_with_backup
- http://erik.debill.org/2011/03/26/csing-backup-with-rails
- http://blog.noizeramp.com/2011/03/31/backing-up-backup-ruby-gem/
- http://www.sebaugereau.com/using-ruby-to-backup-with-beauty
- http://outofti.me/post/4159686269/backup-with-pgbackups
- http://h2ik.co/2011/03/backing-up-with-ruby/
