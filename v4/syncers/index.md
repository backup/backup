---
layout: main
title: Syncers
---

Syncers
=======

Backup includes the following Syncers:

- [Syncer::Cloudfiles][syncer-cloudfiles] (Extra) 
- [Syncer::S3][syncer-s3] (Core)
- [Syncer::RSync][syncer-rsync] (Core)

Syncers are used to keep source directories and their contents synchronized with a destination directory.
Only the contents of the source directories that have changed are transferred to the destination. The source and
destination locations may be on the same physical machine or remote, depending on the Syncer and it's configuration.


Storages vs Syncers
-------------------

[Storages][storages] are part of the main Backup procedure, which consists of the following actions:

- Creating archives (optionally compressed)
- Creating database backups (optionally compressed)
- The packaging *(tar'ing)* of these archives/databases
- The optional encrypting of this final backup _package_
- **The storing of this backup package**

The last step is what [Storages][storages] do.  
Syncers are not part of this procedure, and are run **after** the above procedure has completed.
However, it is a part of the entire backup process for the _model_.
Therefore, if the backup procedure above completes, but a Syncer should fail, then that backup _model_ will be
considered as having failed and you will receive an appropriate [Notification][notifiers].

If you wish to more fully separate this backup procedure from the processing of your Syncer(s), you can simply setup
additional _models_ that only perform your Syncer(s). These can still be run _after_ your backup _model_ has completed
by simply performing multiple triggers.

    backup perform --trigger my_backup,my_syncer

Note that in doing so, you will now receive notifications from each - but notifications for each may also be configured
differently. Also, should the first trigger/model fail, the second trigger/model will still be performed - as long as
the failure isn't due to a fatal error that causes Backup to exit.


Cloud Syncers
-------------

### Supported Cloud Services

- [Amazon S3][syncer-s3]
- [Rackspace CloudFiles][syncer-cloudfiles]

Unlike the [RSync Syncer][syncer-rsync], which has the ability to transfer only parts of individual files,
Cloud Syncers check the MD5 checksum of the local file, then transfers the entire file if the checksum on the remote
does not match.

### Mirroring

When a Cloud Syncer's `mirror` option is set to `true`, Backup will remove all files from the remote that do not exist
locally. File removal is performed after all updated files have been transferred, and performed using _bulk delete_ requests
to minimize the number of requests made to the remote.

### Concurrency

Cloud Syncers may perform several concurrent file transfers by setting the Syncer's `thread_count`. This allows for
greater performance, especially when transferring many small files where more time is spent negotiating with the server
than actually transferring data.

### Error Handling

Each file transfer will be retried if an error occurs. By default, each failed transfer will be retried 10 times,
pausing 30 seconds before each retry. These defaults may be changed using:

```rb
syncer.max_retries = 10
syncer.retry_waitsec = 30
```

When an error occurs that causes Backup to retry the request, the error will be logged. Note that these messages
will be logged as _informational_ messages, so they will not generate warnings. If `max_retries` is exceeded, then an
error will be raised and the Syncer will fail.

If `mirror` is enabled, the file deletion requests will be retried as well. However, if `max_retries` is exceeded for
this operation, it will be logged as a warning.

### Data Integrity

All files are uploaded along with a MD5 checksum the server uses to verify the data received. If the integrity check
fails, the error will be handled as stated above and the file will be retransmitted.


Syncer ID
---------

When you add a Syncer to your Backup Model, you may optionally add a unique identifier.

```rb
sync_with RSync::Push, 'Syncer #1' do |rsync|
  # etc...
end
```

This `syncer_id` will appear in the log messages when the Syncer starts and finishes:

```text
Syncer::RSync::Push (Syncer #1) Started...
...etc...
Syncer::RSync::Push (Syncer #1) Finished!
```

This is not particularly important for Syncers, and is currently only used for the log messages.
It's more of an effort to maintain consistency, where all components that may be added multiple times to a single Backup
Model can use this to uniquely identify themselves. For instance, with [Storages][storages] this is required to keep
[Cycling][storages] data separate, and [Databases][databases] use this to keep their backup dumps separate.

{% include markdown_links %}
