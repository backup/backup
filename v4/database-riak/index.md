---
layout: main
title: Database::Riak (Extra)
---

Database::Riak (Extra)
======================

``` rb
Model.new(:my_backup, 'My Backup') do
  database Riak do |db|
    ##
    # The node from which to perform the backup.
    # default: 'riak@127.0.0.1'
    db.node = 'riak@hostname'
    ##
    # The Erlang cookie/shared secret used to connect to the node.
    # default: 'riak'
    db.cookie = 'cookie'
    ##
    # The user for the Riak instance.
    # default: 'riak'
    db.user = 'riak'
  end
end
```

Riak database dumps produce a single output file created using the `riak-admin backup` command.
This dump file will be stored within your final backup _package_ as `databases/Riak-<node>`

If a `Compressor` has been added, then the resulting dump file will be compressed using the
selected compressor. So, if `Gzip` is the selected compressor, the result would be `databases/Riak-<node>.gz`.

**Note** A backup run with a Riak Database configured must be run as either the `root` user or a user that
has password-less `sudo` privileges.

{% include markdown_links %}
