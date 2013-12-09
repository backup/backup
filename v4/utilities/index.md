---
layout: main
title: Utilities
---

Utilities
=========

Backup uses a number of system command-line utilities. Utilities like `tar` and `cat` are used for every backup job that
includes an Archive or Database (i.e. needs a Storage). Others are used depending on the components or options chosen.

Backup automatically detects these using a `which` command call to find the needed utility in your system's `$PATH`.
However, there may be cases where you need to use a utility that is not in your system's `$PATH`. Or, perhaps you need
to use a specific version of a utility that is different than the one Backup detects.

In these cases, you may configure the full path to the utility needed in your `config.rb` using the following:

```rb
Utilities.configure do
  # General Utilites
  tar   '/path/to/tar'
  tar_dist :gnu   # or :bsd
  cat   '/path/to/cat'
  split '/path/to/split'
  sudo  '/path/to/sudo'
  chown '/path/to/chown'

  # Compressors
  gzip    '/path/to/gzip'
  bzip2   '/path/to/bzip2'

  # Database Utilities
  mongo       '/path/to/mongo'
  mongodump   '/path/to/mongodump'
  mysqldump   '/path/to/mysqldump'
  pg_dump     '/path/to/pg_dump'
  pg_dumpall  '/path/to/pg_dumpall'
  redis_cli   '/path/to/redis-cli'
  riak_admin  '/path/to/riak-admin'

  # Encryptors
  gpg     '/path/to/gpg'
  openssl '/path/to/openssl'

  # Syncer and Storage
  rsync   '/path/to/rsync'
  ssh     '/path/to/ssh'

  # Notifiers
  sendmail  '/path/to/sendmail'
  exim      '/path/to/exim'
end
```

For example, Backup supports both **GNU** and **BSD** system utilities. Most systems ship with a default version, yet
allow you to install the other. The most common being the `tar` utility. On systems that ship with **GNU** `tar`, **BSD**
`tar` can usually be installed and found at `/usr/bin/bsdtar`. While on systems that ship with **BSD** `tar`, you can
usually install **GNU** `tar` and find it at `/usr/bin/gnutar`.

While Backup's use of core utilities like `cat` and `split` are basic enough that it's invocation of these utilities is
compatible with either version, there are differences between **GNU** and **BSD** `tar` which Backup must account for.
Therefore, Backup additionally will detect which version of `tar` is being used. If for some reason this fails, you can
also specify `tar_dist` as `:gnu` or `:bsd` as seen above.

For information about the differences between **GNU** and **BSD** `tar`, see the [Archives][archives] page.

**NOTE:**
Many of Backup's components have their own configuration settings to specify the path to a utility if needed. For
example, you may have a `MySQL` backup where you have to use the `mysqldump_utility` configuration setting so Backup can
find the `mysqldump` utility. In this case, that setting would override the path set using `Utilities.configure`
above. However, these component-level settings may soon be deprecated. It is recommended that you use the
`Utilities.configure` block in your `config.rb` if you need to specify the path to a utility.


{% include markdown_links %}
