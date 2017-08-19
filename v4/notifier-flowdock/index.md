---
layout: main
title: Notifier::Flowdock (Extra)
---

Notifier::Flowdock (Extra)
==========================

``` rb
notify_by FlowDock do |flowdock|
  flowdock.on_success = true
  flowdock.on_warning = true
  flowdock.on_failure = true

  flowdock.token      = "token"
  flowdock.from_name  = 'my_name'
  flowdock.from_email = 'email@example.com'
  flowdock.subject    = 'My Daily Backup'
  flowdock.source     = 'Backup'
  flowdock.tags       = ['prod', 'backup']
  flowdock.link       = 'www.example.com'

  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # flowdock.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

{% include markdown_links %}
