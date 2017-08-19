---
layout: main
title: Splitter (Core)
---

Splitter (Core feature)
=======================

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

    my_backup.tar.gz.enc-aaa
    my_backup.tar.gz.enc-aab
    my_backup.tar.gz.enc-aac
    my_backup.tar.gz.enc-aad

Using the Splitter can help to work around file size limitations. This used to be required for cloud storages,
however these now support large file uploads. See the documentation for your [Storage][storages] for more details.

When using the [Generator][generator], the `--splitter` option may be used to add the Splitter to your generated model.

    $ backup generate:model --trigger my_backup --splitter (etc...)

Note that if you use an [Encryptor][encryptors], the final backup package is split **after** it's encrypted.

The default `suffix_length` is `3`, which allows for 17,576 files. This may be changed if desired using
`split_into_chunks_of 250, 2`, which would allow for 676 files and produce:

    my_backup.tar.gz.enc-aa
    my_backup.tar.gz.enc-ab
    my_backup.tar.gz.enc-ac
    my_backup.tar.gz.enc-ad

_Be aware that having more than 10,000 files in a directory may significantly impact performance._


Restoring a split backup
------------------------

To reassemble a split backup, simply concatenate all the chunks into a single file:

    cat my_backup.tar.gz.enc-aaa \
        my_backup.tar.gz.enc-aab \
        my_backup.tar.gz.enc-aac > my_backup.tar.gz.enc

Or simply use:

    cat my_backup.tar.gz.enc-* > my_backup-tar.gz.enc


{% include markdown_links %}
