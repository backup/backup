---
layout: main
title: Database::Firebird
---

Database::Firebird
====================

``` rb
Model.new(:my_backup, 'My Backup') do
  database Firebird do |db|
    db.name               = "my_database.fdb"
    db.username           = "my_username"
    db.password           = "my_password"
    db.host               = "localhost"
    db.path               = "/var/lib/firebird/2.5/data/teste.fdb"
    db.additional_options = ["-v"]
  end
end
```

Firebird database dumps produce a single output file created using the `gbak` utility.
This dump file will be stored within your final backup _package_ as `databases/Firebird.fbk`.

If a `Compressor` has been added to the backup, the database dump will be piped through
the selected compressor. So, if `Gzip` is the selected compressor, the output would be `databases/Firebird.fbk.gz`.

You may also have the `gbak` command run as another user using `sudo` by specifying `db.sudo_user`.

{% include markdown_links %}
