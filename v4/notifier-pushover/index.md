---
layout: main
title: Notifier::Pushover (Extra)
---

Notifier::Pushover (Extra)
==========================

``` rb
notify_by Pushover do |pushover|
  pushover.on_success = true
  pushover.on_warning = true
  pushover.on_failure = true

  pushover.user = 'USER_KEY' # required
  pushover.token = 'API_KEY' # required
  pushover.title = 'The message title' # optional
  pushover.device = 'The device identifier' # optional
  pushover.priority = '1' # optional

  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # pushover.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

Pushover is a platform for sending and receiving push notifications to Android and iOS devices. Authentication requires the supply of
two keys; an Application (API) token and a user token. Every connected device will require a device name which can then be used for
targeting push notifications.

Messages sent through this notifier are restricted to 512 characters including the supplied title. Applications can send a maximum
of 7,500 messages per month per application (API) key.

Please read the [Pushover API documentation](https://pushover.net/api) for further details of the configuration parameters. Registration
is free, but you do need to purchase the device clients.

{% include markdown_links %}
