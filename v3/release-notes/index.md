---
layout: main
title: Release Notes
---

Release Notes
=============

#### Deprecations

All deprecations are made in such a way that your currently configured backups will still function.
However, the use of deprecated options will cause your backup jobs to complete "with Warnings" until
your configuration files are updated. You can check your configuration using `backup check`.

3.11.1
-----

- Add [Percona XtraBackup][database-mysql] support for MySQL databases.

3.10.0
------

- The S3 [Storage][storages] and [Syncer][syncers] can now handle deleting more than 1000 objects.

- The suffix length for the [Splitter][splitter] may now be configured (defaults to 2).

- The [Redis Database][database-redis] will now retry `invoke_save` if a `SAVE` is already in progress.


3.9.0
-----

- Adds ability to create custom `Models` in your `config.rb` with preconfigured components.
  See the [Preconfigured Models][preconfigured-models] page for details.

- Additional options to pass to fog (and excon) may now be configured for the `S3` and `CloudFiles`
  [Storage][storages] and [Syncer][syncers].

3.8.0
-----

- Allow AWS IAM Profile to be used with the [S3 Storage][storage-s3] and [S3 Syncer][syncer-s3].

- Allow passing SSH connection options for the [SFTP Storage][storage-sftp].

- Add ability to exclude files/folders from all [Syncers][syncers].

- [Archives][archives] now use tar's `--files-from` option to avoid command-line argument list limitations.

- Fix log truncation for [Logger::Logfile][logging] so running a job as `root` (or via sudo) won't
  cause the log file to have root-only write access.

3.7.2
-----

- Fix [S3 Syncer][syncer-s3] under ruby-1.8.7 when directory on the server contains more than 1000 files.

3.7.1
-----

- `SIGINT` (ctrl-c) will now cleanly exit.
- The `Syslog` [Logger][logging] will no longer raise errors if the log message contains format sequences.


3.7.0
-----

- [S3 Storage][storage-s3]

  - Fixes an issue where it was a possible for the request to complete a multipart upload to fail without any
    retries or failure/warnings indicated.

  - If `chunk_size` is too small to accommodate the file being uploaded using multipart uploading, the `chunk_size`
    will now be automatically adjusted and a warning will be logged. The [Splitter][splitter] should be used to
    enforce your desired `chunk_size`.

  - Now works with ruby-1.8.7

- [CloudFiles Storage][storage-cloudfiles]

  - `region` may now be configured.

  - Support for Static Large Objects (SLO) has been added. This is disabled by default for backward compatibility,
    but may be enabled by simply configuring a `segments_container` and `segment_size`.

  - All failed request will now be retried. By default, 10 retries will be attempted with a 30 second pause between,
    which may be changed by configuring `max_retries` and `retry_waitsec`.

  - All files stored may now be scheduled for deletion by the server using the new `days_to_keep` option. This would
    be used in lieu of the [Cycler][storages]. Both may be set, however, to easily transition from using `keep` to using
    `days_to_keep`.

  - Backup package files being removed by the [Cycler][storages] are now removed using a bulk delete request.

- [Cloud Syncers][syncers] (both [S3][syncer-s3] and [CloudFiles][syncer-cloudfiles])

  - Syncers no longer make HEAD requests for each remote file while collecting the remote file's ETag. These are now
    simply taken from one or more `get_bucket` calls, greatly reducing the number of requests during Syncer operation.

  - All files to be removed from the server (if the `mirror` option is set) are now removed after all transfers have
    occurred and are removed using bulk delete requests. Again, reducing the number of requests. Any errors occurring
    while removing objects are also now logged as warnings, instead of causing the job to fail.

  - All file transfers (and delete requests) are now retried when errors occur. By default, 10 retries will be attempted
    with a 30 second pause between, which may be adjusted using `max_retries` and `retry_waitsec`.

  - Syncers will now skip files too large to transfer and log a warning.

- [S3 Syncer][syncer-s3]

  - Now supports Server-Side Encryption and the use of Reduced Redundancy storage.

- [CloudFiles Syncer][syncer-cloudfiles]

  - `region` may now be configured.

- [Notifiers][notifiers]

  - Added a [HttpPost Notifier][notifier-httppost].
  - Added a [Nagios Notifier][notifier-nagios].
  - The [Mail Notifier][notifier-mail] nows works with ruby-1.8.7.
  - The [Mail Notifier][notifier-mail]'s `:exim` delivery method now works.

- [Databases][databases]

  - Added a `sudo_user` option for [PostgreSQL][database-postgresql].


#### Deprecations

- [Dropbox Storage][storage-dropbox]

  - The `chunk_retries` setting has been renamed to `max_retries` for consistency.

- [Cloud Syncers][syncers] (both [S3][syncer-s3] and [CloudFiles][syncer-cloudfiles])

  - `concurrency_type` and `concurrency_level` settings have been removed. Concurrency is now only supported using
    threads, and a new `thread_count` setting has been added to configured the desired number of threads to use.

3.6.0
-----

- All [Notifiers][notifiers] will now retry sending notifications if they fail. By default, they will be retried 10
  times, pausing 30 seconds between retries. These defaults may be adjusted using the `max_retries` and
  `retry_waitsec` options for each Notifier. All retries and failures will be logged.
- [Notifier][notifiers] failures will no longer cause the backup to fail or affect the exit status of `backup perform`.
- The [Mail Notifier][notifier-mail] may now be configured to send an attached log file with `on_success` notifications,
  or not attach the log for `on_warning` and `on_failure` notifications, using a new `send_log_on` option.
- [Before/After Hooks][before-after-hooks] have been added to `Backup::Model`.


#### Deprecations

- [Mail Notifier][notifier-mail]

  - The `sendmail` and `exim` settings used to specify the path to these utilities have been deprecated.
    Previously if these were not set, the default locations specified by the `mail` gem were used. This is no longer the
    case. Backup will now find these utilities using a `which` call and always set their path. If you still need to
    specify the path, see the [Utilities][utilities] page.


3.5.1
-----

- Bug fix for the [Mail Notifier][notifier-mail] when using the `:exim` delivery method.

3.5.0
-----

- Installing or updating Backup with `gem install backup` will now install all required gem dependencies.
  The `backup dependencies` command has been removed.
- Using `gem cleanup` will no longer silently remove Backup's gem dependencies.
- Each release of Backup now specifies exact versions of each of it's gem dependencies.
  Installing an updated version of a gem Backup uses will no longer affect Backup.
- Adds an option to the [PostgreSQL Database][database-postgresql] to dump all databases.
- The [S3 Storage][storage-s3] may now be configured to use
  [Server-Side Encryption](http://docs.aws.amazon.com/AmazonS3/latest/dev/UsingServerSideEncryption.html).
- The [S3 Storage][storage-s3] may now be configured to use
  [Reduced Redundancy Storage](http://docs.aws.amazon.com/AmazonS3/latest/dev/Introduction.html#RRS).

3.4.0
-----

- The [S3 Storage][storage-s3] now uses Amazon's [Multipart Upload](http://docs.aws.amazon.com/AmazonS3/latest/dev/mpuoverview.html)
  for files larger than 5 MiB. All failed requests will be retried 10 times, pausing 30 seconds before each attempt.
  These default values may be adjusted if desired.
- The [S3 Storage][storage-s3] now includes a MD5 checksum which AWS uses to verify the integrity of the uploaded data.
- The [Dropbox Storage][storage-dropbox] will now retry failed requests to _complete_ the chunked upload.

3.3.2
-----

- Update [Dropbox Storage][storage-dropbox] to retry chunk upload on `Timeout::Error` under ruby-1.8.7.

3.3.1
-----

- Bug fix for the [Dropbox Storage][storage-dropbox] when running ruby-1.8.7

3.3.0
-----

- All Database dumps are now stored within the final backup package directly under the `databases/` folder.  
  **This changes the structure of your final backup package**. See the [Databases][databases] page for details.
- Adds a `database_id` to all Databases, used to uniquely identify their dump files within the final backup package.  
  This will be required for certain configurations. See the [Databases][databases] page for details.
- Adds an `oplog` option to the [MongoDB Database][database-mongodb].
- [Riak Database][database-riak] backups may now be run as a user with `sudo` privileges.
- Adds a `use_sudo` option to [Archives][archives] to run the `tar` command using `sudo`.
- Adds a `backup check` command to the [Command Line Options][command-line-options].
- The [Dropbox Storage][storage-dropbox] now uses Dropbox's [Chunked_Uploader](https://www.dropbox.com/developers/core/api#chunked-upload).
  All failed chunks will be retried 10 times, pausing 30 seconds before each attempt. These default values may be adjusted if desired.


#### Deprecations

- [Riak Database][database-riak]

  - The `name` and `group` settings are no longer used.

- [All Databases][databases]

  All Databases had settings (which ended in `_utility`) that allowed you to configure the path to the system utilities
  each database used, such as `mysqldump` or `redis-cli`. If Backup can not find a utility in your `$PATH` using a `which`
  command, the path to the utility may be set using [Utilities][utilities].


#### Warnings

- **New `database_id` Requirement**

  If you have more than one [Database][databases] _of the same type_ (i.e. MySQL, PostgreSQL, etc) defined on
  a single Backup _model_, setting a `database_id` for each instance will be required.
  If this is not done, Backup will auto-generate one for you and log a warning.  
  Using `backup check` will detect this.


3.2.0
-----

- Adds a `root` path option to [Archives][archives] to allow creating tar archives
  with paths relative to the specified `root`, as opposed to the root of the filesystem.
- The [Logger][logging] may be configured to ignore certain warnings if needed.
- `backup perform` will now exit with a non-zero status code if any warnings or errors
  occurred while performing any model/trigger.
- The [Mail Notifier][notifier-mail] may now be configured to use a SSL/TLS connection,
  as opposed to using STARTTLS.
- The [RSync Syncers][syncer-rsync] may now be used with an rsync daemon with both Push and
  Pull operations. Supports direct TCP connection to a daemon, as well as using SSH
  transport to a single-use daemon spawned on the remote.
- The [RSync Storage][storage-rsync] also supports these same rsync daemon options that have
  been added to the RSync Syncers.

#### Deprecations

- [Mail Notifier][notifier-mail]

  - The `enable_starttls_auto` setting has been replaced with a `encryption` setting.

- [RSync Syncers][syncer-rsync]

  - The `additional_options` setting has been changed to `additional_rsync_options`.
  - The `username` setting has been changed to `ssh_user`.
  - The `password` setting has been changed to `rsync_password`.
  - The `ip` setting has been changed to `host`.

- [RSync Storage][storage-rsync]

  - The `local` setting is no longer used. (just don't specify a `host`)
  - The `username` setting has been changed to `ssh_user`.
  - The `password` setting has been changed to `rsync_password`.
  - The `ip` setting has been changed to `host`.

3.1.3
-----

- Fix `backup dependencies --install` so gems may be installed when Bundler is loaded,
  as long as no bundled environment is active.

3.1.2
-----

- Add the `excon` gem as a managed dependency.

  The `fog` gem requires this, but places no constraints on newer versions,
  which leads to incompatibilities.

3.1.1
-----

- Tightened dependency version requirements to maintain stability.

    `fog-1.10.0` changed it's requirement on `net-scp` from `~> 1.0.4` to `~> 1.1.0`.  
    Also, `net-scp > 1.0.4` requires `net-ssh` versions `> 2.6`.  
    Although they appear to work properly, versions of `net-ssh > 2.5.1`  
    do not officially support `ruby-1.8.7` - which we still do (for the moment).

3.1.0
-----

Changes since version `3.0.27`:

- [Riak Database][database-riak] dumps now work when a [Compressor][compressors] is used.
- The system `user` and `group` may now be specified for a [Riak Database][database-riak].
- Fix for segfaults on some systems running ruby-1.8.7.
- [Cloud Syncers][syncers] now dereference symbolic links when scanning local directories.
- The [Hipchat Notifier][notifier-hipchat] now accepts a comma-delimited string of room names.
- If a [Notifier][notifiers] configured to send an `on_failure` notification fails,
  the error that caused it to fail will now be logged.
- Backup can now be configured to log to the `syslog`.
  See [Logging][logging] for details.
- A `--check` option was added for the `backup perform` command.
- Backup's dependency management system has been updated to prevent dependencies
  from activating incompatible versions of other dependencies. Also, version requirements
  for Backup's dependencies have all been updated based on the dependency's versioning policy.
- [Archives][archives] will no longer fail to complete if files being archived are
  changed while `tar` is packaging them. See [Archives][archives] for details, as this
  behavior varies based on whether **GNU** or **BSD** `tar` is being used.
- An `rsyncable` option has been added to the [Gzip Compressor][compressor-gzip].
- The paths to all system utilities that Backup uses may now be set in your `config.rb`.
  See [Utilities][utilities] for details.


---
This page was started with the `3.1.0` release. Please see the commit history for older changes.

{% include markdown_links %}
