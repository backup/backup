---
layout: main
title: Archives
---

Archives
========

Archives are created using the `archive` command:

``` rb
Model.new(:my_backup, 'My Backup') do
  archive :my_archive do |archive|
    # Run the `tar` command using `sudo`
    archive.use_sudo
    # add a file
    archive.add '/path/to/a/file.rb'
    # add a folder (including sub-folders)
    archive.add '/path/to/a/folder/'
    # exclude a file
    archive.exclude '/path/to/a/excluded_file.rb'
    # exclude a folder (including sub-folders)
    archive.exclude '/path/to/a/excluded_folder'
  end
end
```

- You may add as many `add` and `exclude` paths as needed.
- `:my_archive` will be the name of your archive.  
  It will be stored within your final backup _package_ as `archives/my_archive.tar`.
- You may add as many `archive` blocks within your _model_ as you like.  
  Just be sure that each is defined with a unique name.


Specifying a Root Path
----------------------

You have two choices for how the paths within your tar archive will be stored.

- Using the root of the filesystem.
- Using a specified root path.

### Filesystem Root

By default, all paths given to the `add` or `exclude` commands are expanded to their full paths from the root of the
filesystem. Relative paths are expanded based on the current working directory where `backup perform` is executed. When
files are added to the tar archive, the leading `/` is preserved.

For example, given the following:

```rb
archive :my_archive do |archive|
  archive.add 'my_data/save.me'
  archive.add '/opt/save.me.too'
end
```

If `backup perform` is run in `/home/my_user`, your tar file contents would be:

```text
$ tar -tvf my_archive.tar
/home/my_user/my_data/save.me
/opt/save.me.too
```

When extracting this archive, the leading `/` will be automatically stripped by default. So, if you extracted this in
`/home/my_user/tmp`, it would create the following:

```text
$ tar -xvf my_archive.tar
/home/my_user/tmp/home/my_user/my_data/save.me
/home/my_user/tmp/opt/save.me.too
```

However, you may instruct `tar` not to strip the leading `/` using the `-P` option, and it will extract the files back
to their original location:

```text
$ tar -xvPf my_archive.tar
/home/my_user/my_data/save.me
/opt/save.me.too
```

### Specified Root

To set the root path for your archive, you can use the `root` command. When a `root` path is given, all relative paths
added using `add` or `exclude` are taken as relative to the `root` path given.

```rb
archive :my_archive do |archive|
  archive.root '/home/my_user'
  archive.add 'my_data/save.me'
  archive.add '/opt/save.me.too'
end
```

This will instruct `tar` to change it's working directory to `/home/my_user` when creating the archive. In this example,
this means that `tar` will create the following archive:

```text
$ tar -tvf my_archive.tar
my_data/save.me
/opt/save.me.too
```

Note that it's still possible to add files/folders from outside the `root` path using an absolute path. Any leading `/`
will be preserved, so the information above still applies. Be careful when extracting archives with mixed
relative/absolute paths without instructing `tar` to preserve the leading `/`. For example, the path `etc/my_file` and
`/etc/my_file` would both extract to `~/tmp/etc/my_file` by default if extracted in `~/tmp`.

Also note that the `root` path given will be expanded. This means that if given as `archive.root '.'`, the root path
will be the current working directory where `backup perform` was executed. `archive.root '~/'` will expand to your
`$HOME` directory. Of course, absolute paths given will be used as-is.


Compressing Archives
--------------------

To create a compressed archive, simply add a `Compressor` to your Backup _model_.

```rb
Model.new(:my_backup, 'My Backup') do
  archive :my_archive do |archive|
    # add/exclude files/folders
  end

  compress_with Gzip

  # Storages, etc...
end
```

The output of the _tar_ command will be piped through the selected compressor. So, if Gzip is the compressor, the
archive would be saved in your final backup _package_ as `archives/my_archive.tar.gz`.


Additional Tar Options
----------------------

Archives also have a `tar_options` method, which can be used to add additional options to the `tar` command used to
create the archive.

For example, to have `tar` follow symlinks and store extended attributes, you could use:

``` rb
archive :my_archive do |archive|
  archive.add '/path/to/a/file.rb'
  archive.tar_options '-h --xattrs'
end
```

**Note:** Do not add compression flags using `tar_options`. To compress your archives, add a `Compressor`.


Archiving Files That May Change
-------------------------------

Creating an Archive that includes files that may change during the backup process may cause your backup to complete
_with Warnings_. If you have any `Notifiers` configured to send messages `on_success` or `on_warning`, you
will be notified that the job completed _with Warnings_.

Backup supports both **GNU** and **BSD** tar, and each will behave differently when the following actions occur.


### File is Removed

If a file is _removed_ while it is being archived, **GNU** tar will detect this and issue a warning.
However, you may elect to ignore this warning by adding `--warning=no-file-removed` to your `tar_options`.

``` rb
archive :logs do |archive|
  archive.add '/var/apps/my_app/logs/'
  archive.tar_options '--warning=no-file-removed'
end
```

**BSD** tar will issue a warning if this occurs. There is no way to suppress this.

In all cases, the archive will continue to be created and the backup job will continue.
If warnings are issued, this will cause your backup to complete _with Warnings_.


### File is Changed

If a file is _changed_ while it is being archived, **GNU** tar will detect this and issue a warning.
However, you may elect to ignore these warnings by adding `--warning=no-file-changed` to your `tar_options`.

``` rb
archive :logs do |archive|
  archive.add '/var/apps/my_app/logs/'
  archive.tar_options '--warning=no-file-changed'
end
```

**BSD** tar will _not_ issue a warning if this occurs.

In all cases, the archive will continue to be created and the backup job will continue.
If warnings are issued, this will cause your backup to complete _with Warnings_.

**Note:** If you wish to have **GNU** tar ignore warnings when files are changed **or** removed, both options must be used.

``` rb
archive :logs do |archive|
  archive.add '/var/apps/my_app/logs/'
  archive.tar_options '--warning=no-file-changed --warning=no-file-removed'
end
```

### File or Folder Does Not Exist

If a file or folder you have explicitly added using `archive.add` does not exist when the archive is performed, then
both **GNU** and **BSD** tar will output warnings. These warnings may not be suppressed. The archive will continue to be
created, and your backup will be completed _with Warnings_.

If possible, only add parent folders you know will exist. This way if files/folders are removed below the parent
_before_ the archive is performed, no warnings will occur. If they are removed _while_ the archive is being performed,
this will fall under the previous sections where suppressing warnings may be possible.


### File or Folder is Not Readable

If any files or folders are encountered that can not be read, both **GNU** and **BSD** tar will output warnings.
These warnings may not be suppressed. The archive will continue to be created, and your backup will be completed _with Warnings_.

{% include markdown_links %}
