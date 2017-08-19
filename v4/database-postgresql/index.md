---
layout: main
title: Database::PostgreSQL (Core)
---

Database::PostgreSQL (Core feature)
===================================

``` rb
Model.new(:my_backup, 'My Backup') do
  database PostgreSQL do |db|
    # To dump all databases, set `db.name = :all` (or leave blank)
    db.name               = "my_database_name"
    db.username           = "my_username"
    db.password           = "my_password"
    db.host               = "localhost"
    db.port               = 5432
    db.socket             = "/tmp/pg.sock"
    # When dumping all databases, `skip_tables` and `only_tables` are ignored.
    db.skip_tables        = ['skip', 'these', 'tables']
    db.only_tables        = ['only', 'these' 'tables']
    db.additional_options = []
  end
end
```

PostgreSQL database dumps produce a single output file created using the `pg_dump` utility.
This dump file will be stored within your final backup _package_ as `databases/PostgreSQL.sql`.

If a `Compressor` has been added to the backup, the database dump will be piped through
the selected compressor. So, if `Gzip` is the selected compressor, the output would be `databases/PostgreSQL.sql.gz`.

You may also have the `pg_dump` or `pg_dumpall` command run as another user using `sudo` by specifying `db.sudo_user`.
Running these commands as the superuser eliminates the need to provide a password.

{% include markdown_links %}
