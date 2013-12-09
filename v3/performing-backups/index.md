---
layout: main
title: Performing Backups
---

Performing Backups
==================

The most basic command for performing a backup is:

    $ backup perform --trigger my_backup

This command will load the main configuration file, located by default at `~/Backup/config.rb`.
The main configuration file `config.rb` is setup to load all models from the `models/` subdirectory
relative to it's location. So, by default this will be: `~/Backup/models/`.

Therefore, in order for the above command to work, a model must exist which defines the `my_backup` trigger.

``` rb
Model.new(:my_backup, 'My Backup') do
  # backup configuration...
end
```

The best way to create your initial main configuration file and backup model file(s) is to use the [Generator][generator].


Command Line Options
--------------------

**--trigger** (aliases: --triggers, -t)

The `--trigger` option specifies which backup model you wish to run.

    $ backup perform --trigger my_backup
    $ backup perform -t my_backup

To asynchronously perform multiple models, specify multiple triggers in the order you wish the jobs to run.

    $ backup perform --triggers my_backup_1,my_backup_2,my_backup_3 (no spaces)


**--config-file** (alias: -c)

The [Generator][generator] allows you to specify the `--config-path` when generating a model, if you want to store your
configuration in a location other than the default `~/Backup`. If you have done so, then you will need to specify this
location when performing your backup, like so:

    $ backup perform --trigger my_backup --config-file /path/to/config.rb

**--data-path** (alias: -d)

Backup has a [Cycling][storages] feature, which can automatically perform backup rotation for you.
In order to do this, Backup stores a YAML formatted data file with information about your backups,
based on the `Storage` used. This data is stored by default in `~/Backup/data`.
If you are storing this data in another location, it will need to be specified using the `--data-path` option.

    $ backup perform --trigger my_backup --data-path /path/to/data/dir/

**--tmp-path**

During the backup process, all of the Archives and Databases being processed are stored in `~/Backup/.tmp`,
where they are packaged and optionally [split into chunks][splitter] before being transferred to your Storages.
If you want to specify a different directory for this, use:

    $ backup perform --trigger my_backup --tmp-path /path/to/.tmp/

**--cache-path**

If you're using the Dropbox service, then Backup uses the `~/Backup/.cache` directory to store the session cache file
used to authorize connections to Dropbox. To store this in another location, use:

    $ backup perform --trigger my_backup --cache-path /path/to/.cache/

**--root-path** (alias: -r)

If you are happy with the default directory names, but would like to establish this hierarchy in a location other
than `~/Backup`, then you can specify a new root directory using:

    $ backup perform --trigger my_backup --root-path /path/to/root/dir/

The `--root-path` may be specified as an absolute path, or a relative path from where the `backup` command is being run.
In either case, the specified directory must exist.

The command above would then result in:

    --config-file => /path/to/root/dir/config.rb
    --data-path   => /path/to/root/dir/data/
    --log-path    => /path/to/root/dir/log/
    --tmp-path    => /path/to/root/dir/.tmp/
    --cache-path  => /path/to/root/dir/.cache/

If you use the `--root-path` option, you can still specify one of the other options above. However, how that option will
behave depends on how you specify the path for that option. If the other option is specified as an absolute path,
then it will be used as you supply it. If it is given as a relative path, it will be appended to the specified
`--root-path`. Note that while `--root-path` must already exist, all other paths specified will be created if needed.

**Examples:**

```
$ backup perform --trigger my_backup --root-path /new/root/ --tmp-path /tmp/backup

--config-file => /new/root/config.rb
--data-path   => /new/root/data/
--log-path    => /new/root/log/
--tmp-path    => /tmp/backup/
--cache-path  => /new/root/.cache/
```
```
$ backup perform --trigger my_backup --root-path /new/root/ --tmp-path temp/dir/ --config-file my_config.rb

--config-file => /new/root/my_config.rb
--data-path   => /new/root/data/
--log-path    => /new/root/log/
--tmp-path    => /new/root/temp/dir/
--cache-path  => /new/root/.cache/
```

Given you are running `backup` from the directory `/foo`:

```
$ backup perform --trigger my_backup --root-path my_backups --tmp-path temp/dir/

--config-file => /foo/my_backups/config.rb
--data-path   => /foo/my_backups/data/
--log-path    => /foo/my_backups/log/
--tmp-path    => /foo/my_backups/temp/dir/
--cache-path  => /foo/my_backups/.cache/
```
```
$ backup perform --trigger my_backup --root-path . --tmp-path /tmp/backup --config-file cfg_dir/cfg.rb

--config-file => /foo/cfg_dir/cfg.rb
--data-path   => /foo/data/
--log-path    => /foo/log/
--tmp-path    => /tmp/backup/
--cache-path  => /foo/.cache/
```

Checking for Configuration Errors
---------------------------------

The `check` command is used to check your Backup configuration. This command will load your
`config.rb` file, along with all of your _model_ files, and report any Errors or Warnings
generated. This allows to you check your configuration files for syntax errors, as well as
detecting other errors or warning such as the use of deprecated configuration settings.
It is recommended that you run `backup check` whenever you update `backup`.

If your `config.rb` file is not in the default location of `~/Backup/config.rb`, use the
`--config-file` argument to specify it's location.

    $ backup check --config-file /path/to/config.rb

As a convenience, this check may also be performed by adding the `--check` option to your
`backup perform` command, in which case the `trigger` specified will not be performed.

    $ backup perform --trigger my_backup --check

The result of this check will be output to the console only. Any [Logger][logging] configuration
will be ignored. If the check is successful, this command will exit with status code `0`. If there
are any errors/warnings, it will exit with status code `1`.

Note that there are certain actions performed during the backup process may generate errors and/or
warnings this check can not detect. While this will catch most problems, you should of course
use `perform` to confirm your backup jobs will succeed.


Exit Status Codes
-----------------

The `backup perform` command will exit with the following status codes:

**0**: All triggers were successful and no warnings were issued.  
**1**: All triggers were successful, but some had warnings.  
**2**: All triggers were _processed_, but some failed.  
**3**: A fatal error caused Backup to exit. Some triggers may not have been processed.


Passing Arbitrary Variables
---------------------------

If you wish to pass in parameters other then the predefined Command Line Options,
you can do so using environment-variables. For example:

    $ DB_NAME=my_app_production STORAGE_PATH=~/backups/production \
      backup perform --trigger my_backup

Then, you can access these in the `my_backup.rb` model:

```rb
Model.new(:my_backup, 'Description for my_backup') do
  database MongoDB do |db|
    db.name = ENV["DB_NAME"] || "default_name"
    #...
  end

  store_with Local do |local|
    local.path = ENV['STORAGE_PATH']
  end
end
```

Or you can use a single environment-variable to setup a number of local variables:

    $ BACKUP_ENV=production backup perform --trigger my_backup

Then, configure your model using:

```rb
Model.new(:my_backup, 'Description for my_backup') do
  case ENV['BACKUP_ENV']
  when 'production'
    db_name = 'my_app_production'
    storage_path = '~/backups/production'
  when 'development'
    db_name = 'my_app_development'
    storage_path = '~/backups/development'
  else
    raise 'you must provide BACKUP_ENV'
  end

  database MongoDB do |db|
    db.name = db_name
    #...
  end

  store_with Local do |local|
    local.path = storage_path
  end
end
```

{% include markdown_links %}
