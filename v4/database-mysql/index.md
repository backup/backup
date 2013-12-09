---
layout: main
title: Database::MySQL
---

Database::MySQL
===============

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
    # Note: when using `skip_tables` with the `db.name = :all` option,
    # table names must be prefixed with a database name.
    # e.g. ["db_name.table_to_skip", ...]
    db.skip_tables        = ["skip", "these", "tables"]
    db.only_tables        = ["only", "these" "tables"]
    db.additional_options = ["--quick", "--single-transaction"]
  end
end
```

MySQL database dumps produce a single output file created using the `mysqldump` utility.
This dump file will be stored within your final backup _package_ as `databases/MySQL.sql`.

If a `Compressor` has been added to the backup, the database dump will be piped through
the selected compressor. So, if `Gzip` is the selected compressor, the output would be `databases/MySQL.sql.gz`.

{% include markdown_links %}
