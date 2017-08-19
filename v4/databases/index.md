---
layout: main
title: Databases
---

Databases
=========

Backup includes the following Databases:

- [MongoDB][database-mongodb] (Core)
- [MySQL][database-mysql] (Core)
- [PostgreSQL][database-postgresql] (Core)
- [Redis][database-redis] (Core)
- [Riak][database-riak] (Extra)
- [OpenLDAP][database-openldap] (Extra)
- [SQLite][database-sqlite] (Core)


Database Identifiers
--------------------

All Databases allow you to specify a `database_id`. For example:

```rb
database MySQL, :my_id do |db|
  # etc...
end
```

This `database_id` will be added to your dump filename. e.g. `databases/MySQL-my_id.sql`.

When only one of a specific type of Database (MySQL, PostgreSQL, etc) is added to your backup _model_,
this `database_id` is optional. However, if multiple Databases of the same type are added to your _model_,
then a `database_id` will be required for each. This `database_id` keeps the dumps from each Database separate.
Therefore, if multiple Databases of a single type are detected on your _model_ and any of these do not define a
`database_id`, one will be auto-generated and a warning will be logged.

{% include markdown_links %}
