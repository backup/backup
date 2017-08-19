---
layout: main
title: Syncer::RSync (Core)
---

Syncer::RSync (Core feature)
============================

The RSync Syncer supports 3 **types** of operations:

- **RSync::Push** -- Used to sync folders on the local system to a folder on a remote host.

- **RSync::Pull** -- Used to sync folders from a remote host to a folder on the local system.

- **RSync::Local** -- Used to sync folders on the local system to another local folder.


Additionally, `RSync::Push` and `RSync::Pull` support 3 different **modes** of operation:

- **:ssh** (default) -- Connects to the remote host via SSH and does not require the use of an rsync daemon.

- **:ssh_daemon** -- Connects via SSH, then spawns a single-use rsync daemon to allow certain daemon features to be used.

- **:rsync_daemon** -- Connects directly to an rsync daemon on the remote host via TCP.

Note that `:ssh` and `:ssh_daemon` modes transfer data over an encrypted connection. `:rsync_daemon` does not.


### RSync::Push / RSync::Pull Configuration

The configuration of `RSync::Push` and `RSync::Pull` are identical. Only the direction of the transfer differs. The
following shows all the configuration options, along with an explanation of use based on the `mode` of operation.

```rb
Model.new(:my_backup, 'My Backup') do
  sync_with RSync::Push do |rsync| # or: sync_with RSync::Pull do |rsync|
    ##
    # :ssh is the default mode if not specified.
    rsync.mode = :ssh # or :ssh_daemon or :rsync_daemon
    ##
    # May be a hostname or IP address
    rsync.host = "123.45.678.90"
    ##
    # In :ssh or :ssh_daemon mode, this will be the SSH port (default: 22).
    # In :rsync_daemon mode, this is the rsync:// port (default: 873).
    rsync.port = 22
    ##
    # In :ssh or :ssh_daemon mode, this is the remote user name
    # used to connect via SSH. This is only needed if different
    # than the user running Backup.
    #
    # The SSH user must have a passphrase-less SSH key setup
    # to authenticate to the remote host. If this is not desirable,
    # you can provide the path to a specific SSH key for this purpose
    # using SSH's -i option in #additional_ssh_options
    rsync.ssh_user = "ssh_username"
    ##
    # Additional options to the SSH command.
    # Options may be given as a String (as shown) or an Array.
    # These will be added to the rsync command like so:
    #   rsync -a -e "ssh -p 22 <additional_ssh_options>" ...
    rsync.additional_ssh_options = "-i '/path/to/id_rsa'"
    ##
    # In :ssh_daemon or :rsync_daemon mode, this is the user used
    # to authenticate to the rsync daemon. This is only needed if
    # different than the user running Backup.
    rsync.rsync_user = "rsync_username"
    ##
    # In :ssh_daemon or :rsync_daemon mode, if a password is needed
    # to authenticate to the rsync daemon, it may be supplied here.
    # Backup will write this password to a temporary file,
    # then use it with rsync's --password-file option.
    rsync.rsync_password = "my_password"
    # You may also supply the path to your own password file:
    rsync.rsync_password_file = "/path/to/password_file"
    ##
    # Additional options to the rsync command.
    # Options may be given as an Array (as shown) or as a String.
    rsync.additional_rsync_options = ['--sparse', "--exclude='some_pattern'"]
    ##
    # When set to `true` this adds rsync's --delete option,
    # which causes rsync to remove paths from the destination (rsync.path)
    # that no longer exist in the sources (rsync.directories).
    rsync.mirror   = true
    ##
    # When set to `false` this removes rsync's --archive option,
    # Note that rsync won't do anything unless the `additional_rsync_options`
    # option is set. This is helpful when working with fuse filesystems to
    # remove the file permission flags included in the `--archive` flag.
    rsync.archive  = true
    ##
    # When set to `true`, rsync will compress the data being transferred.
    # Note that this only reduces the amount of data sent.
    # It does not result in compressed files on the destination.
    rsync.compress = true

    ##
    # Configures the directories to be sync'd to the rsync.path.
    #
    # For RSync::Push, these are local paths.
    # Relative paths will be relative to the directory where Backup is being run.
    # These paths are expanded, so '~/this/path' will expand to the $HOME directory
    # of the user running Backup.
    #
    # For RSync::Pull, these are paths on the remote.
    # Relative paths (or paths that start with '~/') will be relative to
    # the directory the `ssh_user` is placed in upon logging in via SSH.
    #
    # Note that while rsync supports the use of trailing `/` on source directories
    # to transfer a directory's "contents" and not create the directory itself
    # at the destination, Backup does not. Trailing `/` will be ignored,
    # and any directory added here will be created at the rsync.path destination.
    rsync.directories do |directory|
      directory.add "/var/apps/my_app/public/uploads"
      directory.add "/var/apps/my_app/logs"

      # Exclude files/folders.
      # Each pattern will be passed to rsync's `--exclude` option.
      #
      # Note: rsync is run using the `--archive` option,
      #       so be sure to read the `FILTER RULES` in `man rsync`.
      directory.exclude '*~'
      directory.exclude 'tmp/'
    end

    ##
    # The "destination" path to sync the directories to.
    #
    # For RSync::Push, this will be a path on the remote.
    # Relative paths (or paths that start with '~/') will be relative to
    # the directory the `ssh_user` is placed in upon logging in via SSH.
    #
    # For RSync::Pull, this will be a local path.
    # Relative paths will be relative to the directory where Backup is being run.
    # This path is expanded, so '~/this/path' will expand to the $HOME directory
    # of the user running Backup.
    rsync.path = "backups"
  end
end
```

### RSync::Local Configuration

```rb
sync_with RSync::Local do |rsync|
  rsync.path     = "~/backups/"
  rsync.mirror   = true

  rsync.directories do |directory|
    directory.add "/var/apps/my_app/public/uploads"
    directory.add "/var/apps/my_app/logs"

    # Exclude files/folders.
    # Each pattern will be passed to rsync's `--exclude` option.
    # rsync is run using the `--archive` option,
    # so be sure to read the `FILTER RULES` in `man rsync`.
    directory.exclude '*~'
    directory.exclude 'tmp/'
  end
end
```

With `RSync::Local`, all operations are local to the machine, where `rsync` acts as a smart file copy mechanism.

Both `path` and all paths added to `directories` will be expanded locally. Relative paths will be relative to the
working directory where _backup_ is running. Paths beginning with `~/` will be expanded to the `$HOME` directory of the
user running Backup.

Note that while `rsync` supports the use of trailing `/` on source directories to transfer a directory's
"contents" and not create the directory itself at the destination, Backup does not.
Trailing `/` will be ignored, and any directory added to `rsync.directories` will be created at the `rsync.path` destination.

{% include markdown_links %}
