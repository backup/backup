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

4.4.0
-----

- Fix PostgreSQL sudo option not able to change directories. See [PR #761](https://github.com/backup/backup/pull/761).
- Add support for CC, BCC, and Reply-To headers in AWS SES notifier. See [PR #788](https://github.com/backup/backup/pull/788).
- Fix issue on Mail Notifier with the default `domain` config value being unset when `nil` was given as a value. See [PR #781](https://github.com/backup/backup/pull/781).
- Add support for a custom server url in the HipChat notifier. See [Issue #790](https://github.com/backup/backup/pull/790).
- Update Nokogiri dependency to 1.6.8. See [Issue #799](https://github.com/backup/backup/pull/799).

4.3.0
-----

- Remove ninefold storage. See [issue #757](https://github.com/backup/backup/issues/757).
- Upgrade Dropbox gem and remove patch. See [PR #763](https://github.com/backup/backup/issues/763) and commit [bd837d](https://github.com/backup/backup/commit/bd837db3b8aeb52c6b4bd1ea19851bc06639d9f7).
- Update net-ssh. See [PR #785](https://github.com/backup/backup/issues/785).
- Remove global Mail defaults, set the per instance. See [PR #782](https://github.com/backup/backup/issues/782).

4.2.3
-----

- Allow [rsync syncer][syncer-rsync] to run without the archive option. See [PR #716](https://github.com/backup/backup/pull/716).
- Add support for S3 Infrequent Access storage class. See [PR #725](https://github.com/backup/backup/pull/725).
- Require Ruby's Time library on load. Fixes Storage `.keep` usage with time. See [PR #729](https://github.com/backup/backup/pull/729).
- Update [MongoDB][database-mongodb]'s default port. See [PR #732](https://github.com/backup/backup/pull/732).
- Add `authenticationDatabase` option for [MongoDB][database-mongodb]. See [PR #736](https://github.com/backup/backup/pull/736).

4.2.2
-----

- Fix Storage `keep` using numeric values lower than the current backup count. See [Issue #709](https://github.com/backup/backup/issues/709) and [PR #712](https://github.com/backup/backup/pull/712).

4.2.1 - yanked version
-----

- Allow Storage `keep` to use a Time object. See [PR #701](https://github.com/backup/backup/pull/701).
- Support CC, BCC and reply to fields for [Mail notifier][notifier-mail]. See [PR #707](https://github.com/backup/backup/pull/707).
- Allow timeout configuration for [FTP storage][storage-ftp]. See [PR #702](https://github.com/backup/backup/pull/702).
- Allow [HipChat notifier][notifier-hipchat] to specify the api version. See [PR #696](https://github.com/backup/backup/pull/696).

4.2.0
-----

- Most notifiers now have customizable messages. See [PR #698](https://github.com/backup/backup/pull/698).
- Fix incorrect success codes for packager tar command. See [PR #693](https://github.com/backup/backup/pull/693).

4.1.12
-----

- mysqldump argument options move `user_options` / `additional_options` to the front of the command, see [Issue 618](https://github.com/backup/backup/issues/618)

4.1.11
-----

- Ruby 2.0+ is now required. We dropped support for 1.9.3.
- Remove post install message.
- Add "command" notifier, see [PR 658](https://github.com/backup/backup/pull/658)
- Wait for all storages to finish and don't error out on the first one, see [PR 678](https://github.com/backup/backup/pull/676).

4.1.10
-----

- Fix S3 bug with "frozen" strings in config [Issue 654](https://github.com/backup/backup/pull/654)

4.1.9
-----

- Properly escape passwords in openssl [Issue 651](https://github.com/backup/backup/pull/651)

4.1.8
-----

- Update fog to 1.28.0
- Fix the [Data dog notifier](https://github.com/meskyanichi/backup/pull/642) configuration

4.1.7
-----

- Remove outdated [SQLite][database-sqlite] attributes from template.
- Update to fog v1.27.0

4.1.6
-----

- Update json dependency to 1.8.2

4.1.5
-----

- Update Fog gem dependency, see [#616](https://github.com/meskyanichi/backup/pull/616) for the updates.

4.1.4
-----

- Update Slack notifier configuration, please read PR [#613](https://github.com/meskyanichi/backup/pull/613) for the updates.

4.1.3
-----

- Add `prepare_backup` configuration option MySQL database, see PR [#606](https://github.com/meskyanichi/backup/pull/606) for more information.

4.1.2
-----

- Add AWS [SES][notifier-ses] notifier.

4.1.1
-----

- [Fixed a bug](https://github.com/meskyanichi/backup/pull/592) where Syncer directories and excludes couldn't have default values.

4.1.0
-----

- Changed how the [SQLite][database-sqlite] database worked internally. More details [here](https://github.com/meskyanichi/backup/pull/587).

4.0.7
-----

- Add [DataDog][notifier-datadog] notifier.

4.0.6
-----

- Add [SQLite][database-sqlite] database.

4.0.5
-----

- Add [Pagerduty][notifier-pagerduty] notifier.
- [Fix problem](https://github.com/meskyanichi/backup/issues/581) with PostgreSQL database username and password not being escaped.

4.0.4
-----

- Add [OpenLDAP][database-openldap] database.
- Add [Slack][notifier-slack] icon emoji support.
- Add backtraces to non-configuration related errors.

4.0.3
-----

- Add [Flowdock][notifier-flowdock] notifier.
- Add [Percona XtraBackup][database-mysql] support for MySQL databases.
- Fix [Twitter][notifier-twitter] notifier configuration.

4.0.2
-----

- Add [Slack][notifier-slack] notifier.

4.0.1
-----

- [Storages][storages] and [Syncers][syncers] may now have their `#path` set to an empty string.
  When set to an empty string, the final destination will be relative to the remote's root directory.
  For local destinations, the final destination will be relative to the current working directory.

4.0.0 (and 4.0.0rc1)
--------------------

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

- Adds a `mode` setting to the [Redis Database][database-redis] to support both copying the redis dump file (`:copy`
  mode) and performing a local or remote dump using the `redis-cli --rdb` option (`:sync` mode). Also, the `name` and
  `path` options have been replaced with `rdb_path`.


{% include markdown_links %}
