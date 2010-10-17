# Backup

## A Backup Ruby Gem

__Backup__ is a Ruby Gem written for __Unix__ and __Ruby on Rails (2 and 3)__ environments. It can be used both with and without the Ruby on Rails framework! This gem offers a quick and simple solution to backing up databases such as MySQL/PostgreSQL/SQLite and Files/Folders. All backups can be transferred to Amazon S3, Rackspace Cloud Files, Dropbox Web Service, any remote server you have access to (using either SCP, SFTP or regular FTP), or a Local server. Backup handles Compression, Archiving, Encryption, Backup Cleaning (Cycling) and supports Email Notifications.

## Written for Environments

* UNIX (Ubuntu, OSX, etc.)
* Ruby on Rails 3
* Ruby on Rails 2

## Authors/Maintainers

* [Meskyanichi - Michael van Rooijen](http://github.com/meskyanichi)
* [Fernandoluizao - Fernando Migliorini Luizão](http://github.com/fernandoluizao)

### Contributors

* [dtrueman](http://github.com/dtrueman)
* [Nathan L Smith](http://github.com/smith)
* [Francesc Esplugas](http://github.com/fesplugas)
* [wakiki](http://github.com/wakiki)
* [Dan Hixon](http://github.com/danhixon)
* [Adam Greene](http://github.com/skippy)
* [Dmitriy Novotochinov](http://github.com/trybeee)


## Backup's Current Capabilities

### Storage Methods

* Amazon S3
* Rackspace Cloud Files
* Dropbox (Using your API key/secret from developers.dropbox.com)
* Remote Server (Available Protocols: SCP, SFTP, FTP)
* Local server (Example Locations: Another Hard Drive, Network path)

### Adapters

* MySQL
* PostgreSQL
* SQLite
* MongoDB
* Archive (Any files and/or folders)
* Custom (Anything you can produce using the command line)

### Archiving

Handles archiving for the __Archive__ and __Custom__ adapters.

### Encryption

Handles encryption of __all__ backups for __any__ adapter.
To decrypt a "Backup encrypted file" you can use Backup's built-in utility command:

    sudo backup --decrypt /path/to/encrypted/file.enc

### Backup Cleaning

With Backup you can very easily specify how many backups you would like to have stored (per backup procedure!) on your Amazon S3, Remote or Local server. When the limit you specify gets exceeded, the oldest backup will automatically be cleaned up.

### Email Notifications

You will be able to specify whether you would like to be notified by email when a backup successfully been stored. Simply fill in the email configuration block and set "notify" to true inside the backup procedure you would like to be notified of.

### Quick Example of a Single Backup Setting/Procedure inside the Backup Configuration File

    backup 'mysql-backup-s3' do
      adapter :mysql do
        user      'user'
        password  'password'
        database  'database'
      end
      storage :s3 do
        access_key_id     'access_key_id'
        secret_access_key 'secret_access_key'
        host              's3-ap-southeast-1.amazonaws.com'
        bucket            '/bucket/backups/mysql/'
        use_ssl           true
      end
      keep_backups 25
      encrypt_with_password 'my_password'
      notify true
    end
  
Everything above should be pretty straightforward, so now, using the __trigger__ we specified between
the `backup` and `do` you can execute this backup procedure like so:

__Rails Environment__

    rake backup:run trigger=mysql-backup-s3

__Unix Environment__

    sudo backup --run mysql-backup-s3

That's it. This was a simple example of how it works.

## Want to take Backup for a spin?

### Wiki Pages

[Check out our (15) helpful wiki pages](http://github.com/meskyanichi/backup/wiki)


### Requests

If anyone has any requests, please send us a message or post it in the [issue log](http://github.com/meskyanichi/backup/issues)!


### Suggestions?

Send us a message! Fork the project!


### Found a Bug?

[Report it](http://github.com/meskyanichi/backup/issues)


__Michael van Rooijen | Final Creation. ([http://michaelvanrooijen.com/](http://michaelvanrooijen.com))__
