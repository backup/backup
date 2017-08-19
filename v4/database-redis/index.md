---
layout: main
title: Database::Redis (Core)
---

Database::Redis (Core feature)
==============================

``` rb
Model.new(:my_backup, 'My Backup') do
  database Redis do |db|
    db.mode               = :copy # or :sync
    # Full path to redis dump file for :copy mode.
    db.rdb_path           = '/var/lib/redis/dump.rdb'
    # When :copy mode is used, perform a SAVE before
    # copying the dump file specified by `rdb_path`.
    db.invoke_save        = false
    db.host               = 'localhost'
    db.port               = 6379
    db.socket             = '/tmp/redis.sock'
    db.password           = 'my_password'
    db.additional_options = []
  end
end
```

#### mode

Two modes of operation are supported.

- `:copy` _(default)_

  This mode copies the redis dump file, specified by `rdb_path`. This data will be current as of the last RDB Snapshot
  performed by the server (per your redis.conf settings). If you wish to have Backup issue a `SAVE` command before copying
  this file to ensure it contains the current data, set `db.invoke_save = true`.

- `:sync`

  This mode uses the `redis-cli` utility's `--rdb` option to dump the current redis data. This is implemented by Redis
  internally using a `SYNC` command. The operation is analogous to requesting a `BGSAVE`, then having the dump returned.
  This mode is capable of dumping data from a local or remote redis server.

  **Note:** `:sync` mode requires Redis v2.6 or better.

#### rdb_path

This should be set to the full path to your Redis RDB dump file (see the SNAPSHOTTING section of your redis.conf).
This is only required for `:copy` mode.

#### invoke_save

When set to `true`, Backup will use the `redis-cli` utility to perform a `SAVE` command before copying the dump file
(specified by `rdb_path`). Note that this is a synchronous operation and will block other client requests until
complete. This option is only valid when `:copy` mode is used.

#### host, port, socket

Sets the connectivity options for the `redis-cli` command, which is used in `:sync` mode and for the `invoke_save`
option in `:copy` mode. They are only required if connecting to a remote server (in `:sync` mode), or if your local
server (in `:sync` or `:copy` mode) is not running on the default port (6379).

#### password

Sets the password used for the `redis-cli` utility. Required for `:sync` mode and the `invoke_save` option for `:copy` mode.

#### additional_options

May be set to an Array of options to be passed to all invocations of the `redis-cli` utility.


{% include markdown_links %}
