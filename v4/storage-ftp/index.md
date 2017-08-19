---
layout: main
title: Storage::FTP (Extra)
---

Storage::FTP (Extra)
====================

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
  # Configures open_timeout and read_timeout for Net::FTP
  server.timeout      = 10
end
```

{% include markdown_links %}
