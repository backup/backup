---
layout: main
title: Storage::Local (Core)
---

Storage::Local (Core feature)
=============================

``` rb
store_with Local do |local|
  local.path = '~/backups/'
  # Use a number or a Time object to specify how many backups to keep.
  local.keep = 5
end
```

If multiple Storage options are configured for your backup, then the Local Storage option should be listed **last**.
This is so the Local Storage option can transfer the final backup package file(s) using a _move_ operation.
If you configure a Local Storage and it is _not_ the last Storage option listed in your backup model, then a warning
will be issued and the final backup package file(s) will be transferred locally using a _copy_ operation. This is due to
the fact that the each Storage configured is performed in the order in which you configure it in you model.

{% include markdown_links %}
