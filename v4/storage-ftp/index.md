---
layout: main
title: Storage::FTP
---

Storage::FTP
============

``` rb
store_with FTP do |server|
  server.username     = 'my_username'
  server.password     = 'my_password'
  server.ip           = '123.45.678.90'
  server.port         = 21
  server.path         = '~/backups/'
  # Use a number or a Time object to specify how many backups to keep.
  server.keep         = 5
  server.passive_mode = false
end
```

{% include markdown_links %}
