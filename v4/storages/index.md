---
layout: main
title: Storages
---

Storages
========

Backup includes the following Storages:

- [CloudFiles][storage-cloudfiles] (Core)
- [Dropbox][storage-dropbox] (Extra)
- [S3][storage-s3] (Core)
- [FTP][storage-ftp] (Extra)
- [SCP][storage-scp] (Core)
- [SFTP][storage-sftp] (Core)
- [RSync][storage-rsync] (Core)
- [Local][storage-local] (Core)


Cycling Stored Backups
----------------------

Each Storage (except for RSync) supports the `keep` setting, which specifies how many backups to keep at this location.

``` rb
store_with SFTP do |sftp|
  # Keep number of backups:
  sftp.keep = 5
  # Or until time
  sftp.keep = Time.now - 60 * 60 * 24 * 30 # 1 month from now
end
```

See the documentation for your specific Storage, as other options for managing your stored backups may be available.

#### `keep` as a Number

If a number has been specified and once the `keep` limit has been reached, the oldest backup will be removed.

Note that if `keep` is set to 5, then the 6th backup will be transferred and stored, _before_ the oldest is removed.
So be sure you have space available for `keep + 1` backups.

#### `keep` as Time

When a Time object is set to `keep` it will keep backups _until_ that time.
Everything older than the set time will be removed.

### Storage Identifiers

Each storage supports the ability to specify a `storage_id` to uniquely identify a specific storage.

```rb
store_with SFTP, :my_id do |sftp|
  # etc...
end
```

When using the Cycler, Backup stores information about each stored backup in YAML files in the configured `--data-path`
(see [Performing Backups][performing-backups]). These are stored based on the model's _trigger_ and the Storage used.

```rb
Model.new(:my_backup, 'My Backup') do
  store_with SFTP do |sftp|
    sftp.keep = 5
    # etc...
  end
end
```

Each time the above model is performed, cycling data would be stored in `<data_path>/my_backup/SFTP.yml`.

When a `storage_id` is used, that ID will be appended to this filename.

```rb
Model.new(:my_backup, 'My Backup') do
  store_with SFTP, :my_id do |sftp|
    sftp.keep = 5
    # etc...
  end
end
```

Each time this model is performed, cycling data would be stored in `<data_path>/my_backup/SFTP-my_id.yml`.

This allows you to cycle backups for a single trigger, based on the `storage_id`.

For example, you can store your backup to multiple servers, using the same Storage:

```rb
Model.new(:my_backup, 'My Backup') do

  archive :my_archive do |archive|
    # archive some stuff...
  end

  store_with SFTP, :server_01 do |sftp|
    sftp.username = 'my_username'
    sftp.password = 'my_password'
    sftp.ip       = 'server1.domain.com'
    sftp.port     = 22
    sftp.path     = '~/backups/'
    sftp.keep     = 10
  end

  store_with SFTP, :server_02 do |sftp|
    sftp.username = 'my_username'
    sftp.password = 'my_password'
    sftp.ip       = 'server2.domain.com'
    sftp.port     = 22
    sftp.path     = '~/backups/'
    sftp.keep     = 5
  end

end
```

`:server_01` will keep/cycle the last 10 backups, and `:server_02` the last 5. So you always have your last 5 backups
stored at 2 different locations.

Another example would be to cycle daily/weekly/monthly backups:

```rb
Model.new(:my_backup, 'My Backup') do

  archive :my_archive do |archive|
    # archive some stuff...
  end

  time = Time.now
  if time.day == 1  # first day of the month
    storage_id = :monthly
    keep = 6
  elsif time.sunday?
    storage_id = :weekly
    keep = 3
  else
    storage_id = :daily
    keep = 12
  end

  store_with SFTP, storage_id do |sftp|
    sftp.username = 'my_username'
    sftp.password = 'my_password'
    sftp.ip       = 'server.domain.com'
    sftp.port     = 22
    sftp.path     = "~/backups/#{ storage_id }"
    sftp.keep     = keep
  end

end
```

The cycle data for these backups would be stored in 3 separate YAML files.
`<data_path>/my_backup/SFTP-monthly.yml`
`<data_path>/my_backup/SFTP-weekly.yml`
`<data_path>/my_backup/SFTP-daily.yml`

**Note:** It's not required that the `path` be updated for each unique Storage (as shown in the example), since each
backup is stored in a timestamped folder. Using a separate `path` simply makes it easier to distinguish between each
_type_ of backup.


{% include markdown_links %}
