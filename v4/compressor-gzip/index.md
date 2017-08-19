---
layout: main
title: Compressor::Gzip (Core)
---

Compressor::Gzip (Core feature)
===============================

``` rb
Model.new(:my_backup, 'My Backup') do

  # Archives, Databases, etc...

  # to use default settings
  compress_with Gzip

  # to customize settings
  compress_with Gzip do |compression|
    compression.level = 6
    compression.rsyncable = true
  end
end
```

Gzip is the fastest compressor and requires the least amount of memory.
The compression `level` for Gzip is **6** by default, and may be set from 1 to 9.

Additionally, the `rsyncable` option may be set to `true`.
This option directs `gzip` to compress data using an algorithm that allows `rsync` to efficiently detect changes.
This is especially useful when the [RSync Storage][storage-rsync] is used.

The `--rsyncable` option is only available on patched versions of `gzip`. While most distributions apply this patch,
this option may not be available on your system. If it's not available, Backup will log a warning and continue to use
the compressor without this option. Also note that the use of this option _will not_ affect the ability of an
non-patched version of `gzip` to decompress files compressed with this option.


{% include markdown_links %}
