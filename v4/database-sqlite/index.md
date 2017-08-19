---
layout: main
title: Database::SQLite (Core)
---

Database::SQLite (Core feature)
===============================

``` rb
Model.new(:my_backup, 'My Backup') do
  database SQLite do |db|
    # Path to database
    db.path               = "/path/to/my/sqlite/db.sqlite3"
    # Optional: Use to set the location of this utility
    #   if it cannot be found by name in your $PATH
    db.sqlitedump_utility = "/opt/local/bin/sqlite3"
  end
end
```

{% include markdown_links %}
