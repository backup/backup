---
layout: main
title: Upgrading
---

Upgrading v3 to v4
==================

Several changes have been made in v4.x that are not backward compatible with v3.x.
These changes must be addressed before you run any backups with v4.x.

It's recommended you update to the latest v3.x release first,
or be sure you understand the changes since you're current release.


Backup's Config File
--------------------

You must update your `config.rb` file for v4.x. Simply save a copy of your current `config.rb`,
then generate a new `config.rb` and move your settings to the new file.

    $ mv /path/to/config.rb /path/to/config.rb.sav
    $ backup generate:config --config-file /path/to/config.rb


Storage Cycling
---------------

If you use Backup's [Cycler][storages] (i.e. the `keep` option), then you will need to move the directory holding the
cycling data YAML files. The default location was `~/Backup/data`. This has been changed to `~/Backup/.data`. Simply
rename the existing directory.

    $ mv ~/Backup/data ~/Backup/.data

If you are already setting `--data-path`, then you are not affected. However, if you are changing this path by setting
`--root-path`, then you will need to move this directory as well.

    $ mv /new/root/data /new/root/.data

If this is not done, all backups stored using v3.x will remain until you manually remove them.

Dropbox's Cached Authorized Session
-----------------------------------

The `--cache-path` command line option has been removed. This was used for setting the path where cached authorized
Dropbox sessions are stored. If you were specifying this path, then you will need to move this setting into your
`config.rb` or model files.

```rb
# In config.rb, as a default
Storage::Dropbox.defaults do |dropbox|
  dropbox.cache_path = '/my/cache/path'
end

# In your model, for a specific backup
Model.new(:my_backup, 'My Backup') do
  store_with Dropbox do |dropbox|
    dropbox.cache_path = '/my/cache/path'
  end
end
```

The default path of `~/Backup/.cache` has not changed.

This also does not affect those changing this path by setting `--root-path`.
The default `cache_path` is `.cache`, which will be relative to your `--root-path`.


RSync Storage Locations
-----------------------

If you are using the default `:ssh` mode, or storing to a local path (i.e. no `host` specified),
then the path where your backup files are stored has changed.

In v3.x, the `trigger` for your backup was being added to the `path` you specified. If you set the `path` to
`~/my/folder`, your backup was being stored in `~/my/folder/my_trigger`. This extra folder will no longer be added to
the path. The files will be synced to the `path` you specify.

Therefore, you must do one of two things:

1. Change the `path` being used so it includes the trigger folder Backup is no longer adding.

    For a backup model with a trigger named `my_trigger`, if you have `path` set to `~/my/folder`, change this to
    `~/my/folder/my_trigger`.

2. Move your data to the new location.

    For the same example above, you would move the backup data stored in `~/my/folder/my_trigger` into the new location
    of `~/my/folder`.

If you're using the `:ssh_daemon` or `:rsync_daemon` option, then you are not affected.


Mail Notifier
-------------

The default value for the `encryption` option has been changed from `:none` to `:starttls`.


Redis Database
--------------

All users must review the [updated documentation][database-redis] and update their models. A new `mode` setting has been
added, and the `name` and `path` settings have been replaced with a `rdb_path` setting.


{% include markdown_links %}
