---
layout: main
title: Storage::Dropbox (BROKEN)
---

Storage::Dropbox (BROKEN)
========================

**Important:** This feature no longer works, due to Dropbox closing down version 1 of their API. It will be removed in the next release of Backup.  [GitHub issue #838](https://github.com/backup/backup/issues/899) has a discussion of this issue, and an unsupported patch to re-enable access to Dropbox with Backup version 4.

``` rb
store_with Dropbox do |db|
  db.api_key     = "my_api_key"
  db.api_secret  = "my_api_secret"
  # Sets the path where the cached authorized session will be stored.
  # Relative paths will be relative to ~/Backup, unless the --root-path
  # is set on the command line or within your configuration file.
  db.cache_path  = ".cache"
  # :app_folder (default) or :dropbox
  db.access_type = :app_folder
  db.path        = "/path/to/my/backups"
  # Use a number or a Time object to specify how many backups to keep.
  db.keep        = 25
end
```

To use the Dropbox service as a backup storage, you need two things:

* A Dropbox Account (Get one for free here: [dropbox.com](https://www.dropbox.com))
* A Dropbox App (Create one for free here: [developer.dropbox.com](https://www.dropbox.com/developers/apps))

The default `db.access_type` is `:app_folder`. This is the default for Dropbox accounts.
If you have contacted Dropbox and upgraded your account to _Full Dropbox Access_, then you will need to set the
`db.access_type` to `:dropbox`.

**Note:** You must run your backup to Dropbox manually the first time to authorize your machine with your
Dropbox account. When you manually run your backup, backup will provide you with a URL which you must visit with your
browser. Once you've authorized your machine, Backup will write out the session to a cache file and from there on Backup
will use the cache file and won't prompt you to manually authorize, meaning you can run it in the background as normal
using for example a Cron task.


### Chunked Uploader

The Dropbox Storage uses Dropbox's [/chunked_upload](https://www.dropbox.com/developers/core/api#chunked-upload) API.
By default, this will upload the final backup package file(s) in chunks of 4 MiB. If an error occurs while uploading a
chunk, Backup will retry the failed chunk 10 times, pausing 30 seconds between retries. If you wish to customize these
values, you can do so as follows:

```rb
store_with Dropbox do |db|
  db.chunk_size     = 4 # MiB
  db.max_retries    = 10
  db.retry_waitsec  = 30
end
```

**Note:** This has nothing to do with Backup's [Splitter][splitter]. If you have a Splitter defined on your _model_
using `split_into_chunks_of`, your final backup package will still be split into multiple files, and each of those files
will be uploaded to Dropbox.


{% include markdown_links %}
