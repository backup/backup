---
layout: main
title: Compressor::Bzip2 (Extra)
---

Compressor::Bzip2 (Extra)
=========================

``` rb
Model.new(:my_backup, 'My Backup') do

  # Archives, Databases, etc...

  # to use default settings
  compress_with Bzip2

  # to customize settings
  compress_with Bzip2 do |compression|
    compression.level = 9
  end
end
```

Bzip2 will give you higher compression than Gzip, but will take longer and use more memory.
The compression `level` for Bzip2 is **9** by default, and may be set from 1 to 9.


{% include markdown_links %}
