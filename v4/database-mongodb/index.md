---
layout: main
title: Database::MongoDB (Core)
---

Database::MongoDB (Core feature)
================================

``` rb
Model.new(:my_backup, 'My Backup') do
  database MongoDB do |db|
    db.name               = "my_database_name"
    db.username           = "my_username"
    db.password           = "my_password"
    db.host               = "localhost"
    db.port               = 27017
    db.ipv6               = false
    db.only_collections   = ['only', 'these' 'collections']
    db.additional_options = []
    db.lock               = false
    db.oplog              = false
  end
end
```

MongoDB database dumps are created using the `mongodump` utility, which will output several files in a folder hierarchy
like `<databases>/<collections>`. Backup creates this hierarchy under a directory named `MongoDB`. If you specified a
`database_id` (see below), that will be appended. e.g. `MongoDB-my_id`.

Once the dump is complete, Backup packages this folder into a single tar archive. This archive will be in your final
backup package as `databases/MongoDB.tar`.

If a `Compressor` has been added to the backup, the packaging of this folder will be piped through
the selected compressor. So, if `Gzip` is the selected compressor, the output would be `databases/MongoDB.tar.gz`.


**db.lock**

If `db.lock` is set to `true`, Backup will issue a `fsyncLock()` command to force `mongod` to flush all pending
write operations to disk and lock the _entire mongod instance_ for the duration of the dump. Note that if you
have _Profiling_ enabled on your instance, this will be disabled (and will not be re-enabled when the dump completes).

**db.oplog**

If `db.oplog` is set to `true`, the `--oplog` option will be added to the `mongodump` command. This creates a
database dump that includes an _oplog_ to create a point-in-time snapshot of the current state of the _mongod_ instance.

This is available for all nodes that maintain an _oplog_, including all members of a replica set, as well as master
nodes in master/slave replication deployments. This is preferable over using `db.lock`, since the node being dumped does
not need to be locked.

{% include markdown_links %}
