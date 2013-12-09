---
layout: main
title: Database::Redis
---

Database::Redis
===============

``` rb
Model.new(:my_backup, 'My Backup') do
  database Redis do |db|
    ##
    # From `dbfilename` in your `redis.conf` under SNAPSHOTTING.
    # Do not include the '.rdb' extension. Defaults to 'dump'
    db.name               = 'dump'
    ##
    # From `dir` in your `redis.conf` under SNAPSHOTTING.
    db.path               = '/var/lib/redis'
    db.password           = 'my_password'
    db.host               = 'localhost'
    db.port               = 6379
    db.socket             = '/tmp/redis.sock'
    db.additional_options = []
    db.invoke_save        = true
  end
end
```

The Redis database dump file for the above configuration would be copied from
`/var/lib/redis/dump.rdb` to `databases/Redis.rdb`.

If a `Compressor` has been added to the backup, then the database dump file would be copied using the
selected compressor. So, if `Gzip` is the selected compressor, the result would be `databases/Redis.rdb.gz`.


**db.invoke_save**

If `db.invoke_save` is set to `true`, it will perform a `SAVE` command using `redis-cli` before backing up the dump
file, so that the dump file is at it's most recent state.

{% include markdown_links %}
