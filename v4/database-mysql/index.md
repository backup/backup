---
layout: main
title: Database::MySQL (Core)
---

Database::MySQL (Core feature)
==============================

``` rb
Model.new(:my_backup, 'My Backup') do
  database MySQL do |db|
    # To dump all databases, set `db.name = :all` (or leave blank)
    db.name               = "my_database_name"
    db.username           = "my_username"
    db.password           = "my_password"
    db.host               = "localhost"
    db.port               = 3306
    # supplying a `socket` negates `host` and `port`
    db.socket             = "/tmp/mysql.sock"
    # specifying `sudo_user` will run the backup utility on behalf of that Unix user (instead of current one)
    db.sudo_user          = "root"
    # Note: when using `skip_tables` with the `db.name = :all` option,
    # table names must be prefixed with a database name.
    # e.g. ["db_name.table_to_skip", ...]
    db.skip_tables        = ["skip", "these", "tables"]
    db.only_tables        = ["only", "these" "tables"]
    db.additional_options = ["--quick", "--single-transaction"]
    db.prepare_backup = true # see https://github.com/meskyanichi/backup/pull/606 for more information
  end
end
```

By default, MySQL database dumps produce a single output file created using the `mysqldump` utility.
This dump file will be stored within your final backup _package_ as `databases/MySQL.sql`.

If a `Compressor` has been added to the backup, the database dump will be piped through
the selected compressor. So, if `Gzip` is the selected compressor, the output would be `databases/MySQL.sql.gz`.

### Percona XtraBackup (innobackupex) ###

``` rb
Model.new(:my_backup, 'My Physical Backup') do
  database MySQL do |db|
    db.backup_engine      = :innobackupex
    db.name               = "my_database_name"
    db.username           = "my_username"
    db.password           = "my_password"
    db.host               = "localhost"
    db.port               = 3306
    # supplying a `socket` negates `host` and `port`
    db.socket             = "/tmp/mysql.sock"
    # specifying `sudo_user` will run the backup utility on behalf of that Unix user (instead of current one)
    db.sudo_user          = "root"
    # Connection parameters and additional_options work the
    # same as above (only `skip_tables`/`only_tables` are not
    # supported)
    db.prepare_options    = ["--use-memory=4G"]
    db.verbose            = true
  end
end
```

Setting `backup_engine` to `:innobackupex` will use [Percona XtraBackup](http://www.percona.com/doc/percona-xtrabackup/2.1/)'s `innobackupex` utility instead of `mysqldump` to perform the backup. It doesn't require Percona MySQL, but Percona XtraBackup must be installed.

Backups are created and [prepared for restoring](https://www.percona.com/doc/percona-xtrabackup/2.1/innobackupex/preparing_a_backup_ibk.html) before compressing/splitting/etc., to reduce restore times. Because of this, the server (typically a slave) needs to have available disk space for a database copy (in addition to the space needed for the backup itself).

The `skip_tables` and `only_tables` configurations won't work, because partial physical backups require [special conditions](https://www.percona.com/doc/percona-xtrabackup/2.1/innobackupex/partial_backups_innobackupex.html) (however, if you meet them, just add the proper [parameters](https://www.percona.com/doc/percona-xtrabackup/2.1/innobackupex/partial_backups_innobackupex.html) to `additional_options`).

A few (optional) extra configurations are available:

- **`prepare_options`**: XtraBackup backups are done in two steps: *copy* and *prepare*. In the same fashion that `additional_options` are applied to the copy command, these are applied to the prepare one.

- **`verbose`**: `innobackupex` outputs operational messages to stderr by default, causing a warning even on successful completion, so it is suppressed by default. Setting this paremeter to `true` will display those (which is useful during implementation/debugging), but will log/notify the bacup as "successful with warnings".

{% include markdown_links %}
