---
layout: main
title: Storage::Ninefold
---

Storage::Ninefold
=================

``` rb
store_with Ninefold do |nf|
  nf.storage_token   = 'my_storage_token'
  nf.storage_secret  = 'my_storage_secret'
  nf.path            = '/path/to/my/backups'
  # Use a number or a Time object to specify how many backups to keep.
  nf.keep            = 10
end
```

You will need a Ninefold account. You can get one [here](http://ninefold.com/cloud-storage/).

{% include markdown_links %}
