---
layout: main
title: Release Notes
---

Release Notes
=============

#### Deprecations

All deprecations are made in such a way that your currently configured backups will still function.
However, the use of deprecated options will cause your backup jobs to complete "with Warnings" until
your configuration files are updated. You can check your current configuration using `backup check`.
See the [Performing Backups][performing-backups] page for details.

#### Upgrading from v3.x

Before you upgrade to v4.x, see the [Upgrading][upgrading] page.
Several changes have been made which will require your attention before you run your first backup using v4.x.


4.0.0
-----

- Ruby 1.8.7 and 1.9.2 are no longer supported.

- All deprecated v3.x usage has been removed.

- Command line path options (`--root-path`, `--tmp-path`, `--data-path`) may now be set in your `config.rb`.

- The `--cache-path` command line option was removed.
  The [Dropbox Storage][storage-dropbox] now has a `cache_path` option for configuring this path.

- The default `--data-path`, where [Cycler][storages] YAML files are stored,
  has been changed from `~/Backup/data` to `~/Backup/.data`.

- The `encryption` setting for the [Mail Notifier][notifier-mail] now defaults to `:starttls`

- The `backup decrypt` command has been removed. Encrypted backups should be decrypted using `gpg` or `openssl`.
  See the documentation for your [Encryptor][encryptors] for instructions.

- The [RSync Storage][storage-rsync] no longer appends a folder named after the trigger
  when `:ssh` mode is used or the `path` is local (no `host` given).

- The [Splitter][splitter] is no longer added to generated models by default, and the default `suffix_length` is now 3.

- The `--config-path` option for the [Generator][generator] commands is now `--config-file`, and `generate:config` may
  now be used to generate a configuration file using a name other than `config.rb`.


{% include markdown_links %}
