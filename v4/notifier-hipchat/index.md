---
layout: main
title: Notifier::Hipchat (Extra)
---

Notifier::Hipchat (Extra)
=========================

``` rb
notify_by Hipchat do |hipchat|
  hipchat.on_success = true
  hipchat.on_warning = true
  hipchat.on_failure = true

  hipchat.success_color = 'green'
  hipchat.warning_color = 'yellow'
  hipchat.failure_color = 'red'

  hipchat.token = 'hipchat api token' # required
  hipchat.from = 'DB Backup' # required
  hipchat.rooms_notified = ['activity'] # required
  hipchat.api_version = 'v1'

  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # hipchat.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

Hipchat is a hosted private chat service. Backup can connect to Hipchat to post notices in room via the API. To get an
API token, you must be logged in as an admin. Click the _Group Admin_ tab at the top, then click _API_ and then create a
new token for backup. A "notification" key type is sufficient.

The Hipchat notifier can notify on multiple rooms that you specify by name. `rooms_notified` may be set using a single
room name (`hipchat.rooms_notified = 'my_room'`), a comma-delimited list of names (`hipchat.rooms_notified = 'my_room,
another room'`), or an Array of names (as shown above).

Please see the [Hipchat API documents](https://www.hipchat.com/docs/api/method/rooms/message) for a list of available colors.

{% include markdown_links %}
