---
layout: main
title: Splitter
---

Splitter
========

``` rb
Model.new(:my_backup, 'Description for my_backup') do
  ##
  # Split [Splitter]
  #
  # Split the backup file in to chunks of 250 megabytes
  # if the backup file size exceeds 250 megabytes
  #
  split_into_chunks_of 250

  # etc...
end
```

The Splitter uses the GNU or BSD `split` utility to split the final backup package into multiple files.
If your final backup package is `my_backup.tar.gz.enc` and is 1 GiB in size, it would split this file into

    my_backup.tar.gz.enc-aa
    my_backup.tar.gz.enc-ab
    my_backup.tar.gz.enc-ac
    my_backup.tar.gz.enc-ad

Using the Splitter can help to work around file size limitations. This used to be required for cloud storages,
however these now support large file uploads. See the documentation for your [Storage][storages] for more details.

The Splitter is added to all generated model files by default, but can be disabled using the `--no-splitter`
option with the [Generator][generator]:

    $ backup generate:model --trigger my_backup --no-splitter (etc...)

Note that if you use an [Encryptor][encryptors], the final backup package is split **after** it's encrypted.


Suffix Length
-------------

You can also specify the suffix length using `split_into_chunks_of 250, 3`, which would create

    my_backup.tar.gz.enc-aaa
    my_backup.tar.gz.enc-aab
    my_backup.tar.gz.enc-aac
    my_backup.tar.gz.enc-aad

By default, the suffix length is `2` (676 possible files). Using a 250 MiB chunk size, the maximum size of your backup
must not exceed ~177 GiB `(250 * 1024**2) * 676`. Using a suffix length of `3` would allow for 17,576 files.
_Be aware that having more than 10,000 files in a directory may significantly impact performance._

**Note:** The suffix length will default to `3` in Backup v4.x.


Restoring a split backup
------------------------

To reassemble a split backup, simply concatenate all the chunks into a single file:

    cat my_backup.tar.gz.enc-aa \
        my_backup.tar.gz.enc-ab \
        my_backup.tar.gz.enc-ac > my_backup.tar.gz.enc

Or simply use:

    cat my_backup.tar.gz.enc-* > my_backup-tar.gz.enc


{% include markdown_links %}
