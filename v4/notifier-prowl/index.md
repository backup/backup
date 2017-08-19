---
layout: main
title: Notifier::Prowl (Extra)
---

Notifier::Prowl (Extra)
=======================

``` rb
notify_by Prowl do |prowl|
  prowl.on_success = true
  prowl.on_warning = true
  prowl.on_failure = true

  prowl.application = 'my_application'  # Example: Server Backup
  prowl.api_key     = 'my_api_key'

  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # prowl.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

Prowl is an iOS push notification gateway. Backup can connect to Prowl and deliver success and/or failure notifications
directly to your iOS device. All you need is a [Prowl](http://www.prowlapp.com/) account. Go to the _API keys_ tab after
registration, generate a key and copy/paste it into your notifier configuration.

{% include markdown_links %}
