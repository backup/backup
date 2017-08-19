---
layout: main
title: Storage::RSync (Core)
---

Storage::RSync (Core feature)
=============================

Say you just transferred a backup of about 2000MB in size. 12 hours later the Backup gem packages a new backup file for
you and it appears to be 2050MB in size. Rather than transferring the whole 2050MB to the remote server, it'll lookup
the difference between the source and destination backups and only transfer the bytes that changed. In this case it'll
transfer only around 50MB rather than the full 2050MB.

**Note:** If you only want to sync particular folders on your filesystem to a backup server, then be sure to take a look
at [Syncer::RSync][syncer-rsync], which in most cases is more suitable for this purpose.

### Configuring the RSync Storage

There are 3 different **modes** of _remote_ operation available:

- **:ssh** (default) -- Connects to the remote host via SSH and does not require the use of an rsync daemon.

- **:ssh_daemon** -- Connects via SSH, then spawns a single-use rsync daemon to allow certain daemon features to be used.

- **:rsync_daemon** -- Connects directly to an rsync daemon on the remote host via TCP.

Note that `:ssh` and `:ssh_daemon` modes transfer data over an encrypted connection. `:rsync_daemon` does not.

If no `host` is configured, the operation will be _local_ and the only options used would be `path` and
`additional_rsync_options`.

The following is all of the configuration options available, along with information about there use depending on which
`mode` you are using:

```rb
store_with RSync do |storage|
  ##
  # :ssh is the default mode if not specified.
  storage.mode = :ssh # or :ssh_daemon or :rsync_daemon
  ##
  # May be a hostname or IP address.
  storage.host = "123.45.678.90"
  ##
  # In :ssh or :ssh_daemon mode, this will be the SSH port (default: 22).
  # In :rsync_daemon mode, this is the rsync:// port (default: 873).
  storage.port = 22
  ##
  # In :ssh or :ssh_daemon mode, this is the remote user name
  # used to connect via SSH. This is only needed if different
  # than the user running Backup.
  #
  # The SSH user must have a passphrase-less SSH key setup to
  # authenticate to the remote host. If this is not desirable,
  # you can provide the path to a specific SSH key for this purpose
  # using SSH's -i option in #additional_ssh_options
  storage.ssh_user = "ssh_username"
  ##
  # Additional options for the SSH command.
  # Options may be given as a String (as shown) or an Array.
  # These will be added to the rsync command like so:
  #   rsync -a -e "ssh -p 22 <additional_ssh_options>" ...
  storage.additional_ssh_options = "-i '/path/to/id_rsa'"
  ##
  # In :ssh_daemon or :rsync_daemon mode, this is the user name
  # used to authenticate to the rsync daemon. This is only needed
  # if different than the user running Backup.
  storage.rsync_user = "rsync_username"
  ##
  # In :ssh_daemon or :rsync_daemon mode, if a password is needed
  # to authenticate to the rsync daemon, it may be supplied here.
  # Backup will write this password to a temporary file, then use it
  # with rsync's --password-file option.
  storage.rsync_password = "my_password"
  # You may also supply a path to your own password file:
  storage.rsync_password_file = "/path/to/password_file"
  ##
  # Additional options to the rsync command.
  # Options may be given as an Array (as shown) or as a String.
  storage.additional_rsync_options = ['--sparse', "--exclude='some_pattern'"]
  ##
  # When set to `true`, rsync will compress the data being transferred.
  # Note that this only reduces the amount of data sent.
  # It does not result in compressed files on the destination.
  storage.compress = true
  ##
  # The path to store the backup package file(s) to.
  #
  # If no `host` is specified, this will be a local path.
  # Otherwise, this will be a path on the remote server.
  #
  # In :ssh mode, relative paths (or paths that start with '~/')
  # will be relative to the directory the `ssh_user` is placed in
  # upon logging in via SSH.
  #
  # For both local and :ssh mode operation, the given path will be
  # created if it does not exist. (see additional notes about `path` below)
  #
  # For :ssh_daemon and :rsync_daemon modes, `path` will be a named rsync
  # module; optionally followed by a path. In these modes, the path
  # referenced must already exist on the remote server.
  #
  storage.path = "~/backups"
end
```

I encourage you to look into using `:ssh_daemon` mode. Setting this up can be as simple as adding a `rsyncd.conf` file
(with 0644 permissions) in the $HOME dir of the `ssh_user` on the remote system (most likely the same username running
the backup) with the following contents:

```text
[backup-module]
path = backups
read only = false
use chroot = false
```

Then simply use `storage.path = 'backup-module'`, making sure `~/backups` exists on the remote.

### Using Compression

Only the [Gzip Compressor][compressor-gzip] should be used with your backup model if you use this storage option.
And only if your version of `gzip` supports the `--rsyncable` option, which allows `gzip` to compress data using an
algorithm that allows `rsync` to efficiently detect changes. Otherwise, even a small change in the original data will
result in nearly the entire archive being transferred.

### Using Encryption

An `Encryptor` should **not** be added to your backup model when using this storage option. Encrypting the
final archive will make it impossible for `rsync` to distinguish changes between the source and destination files.
This will result in the entire backup archive will be transferred, even if only a small change was made to the original
files.

### Splitter

Using the [Splitter][splitter] with the RSync Storage is not recommended.

If you use the Splitter, understand that the RSync Storage will never remove any files from `path`.
For example, say your backup usually results in 2 chunk files being stored: `my_backup.tar-aa` and `my_backup.tar-ab`.
Then one day, it results in 3 chunks for some reason - an additional `my_backup.tar-ac` file.
You discover a ton of files you meant to delete the next day, and your backup returns to it's normal 2 chunks.
That 3rd `my_backup.tar-ac` file will remain until you delete it.

Also, changes that alter one file would cause the resulting changes to all subsequent files to be transmitted,
as unchanged data is shifted to/from these files.


### Cycling

The RSync Storage option _does not_ support cycling, so you cannot specify `server.keep = num_of_backups` here. With
this storage, only **one** copy of your backup archive will exist on the remote, which `rsync` _updates_ with the changes
it detects. If you're looking for a way to keep rotated backups, you can simply change the `path` each time the backup runs.

For example, to keep:

- Monthly backups
- Weekly backups, rotated each month
- Daily backups, rotated each week
- Hourly backups, rotated every 4 hours

Create the following backup model:

```rb
Model.new(:my_backup, 'My Backup') do
  # Archives, Databases...

  # Make sure you compress your Archives and Databases
  # using an rsync-friendly algorithm  
  compress_with Gzip do |gzip|
    gzip.rsyncable = true
  end

  store_with RSync do |storage|
    time = Time.now
    if time.hour == 0   # first hour of the day
      if time.day == 1  # first day of the month
        # store a monthly
        path = time.strftime '%B'             # January, February, etc...
      elsif time.sunday?
        # store a weekly
        path = "Weekly_#{ time.day / 7 + 1 }" # Weekly_1 thru Weekly_5
      else
        # store a daily
        path = time.strftime '%A'             # Monday thru Saturday
      end
    else
      # store an hourly
      path = "Hourly_#{ time.hour % 4 + 1 }"  # Hourly_1 thru Hourly_4
    end
    storage.path = "~/backups/#{ path }"
  end
end
```

Then simply setup cron to run the job every hour.  
Note that this will require space for 27 full backups.  
You could use a different `storage.host` for the monthly, weekly, etc...  
Remember that for `:ssh_daemon` and `:rsync_daemon` modes, each of these paths must already exist.

Or of course, think of your own use cases (and let me know if you figure out any good ones!).

{% include markdown_links %}
