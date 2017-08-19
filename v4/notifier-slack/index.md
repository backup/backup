---
layout: main
title: Notifier::Slack (Core)
---

Notifier::Slack (Core feature)
==============================

``` rb
notify_by Slack do |slack|
  slack.on_success = true
  slack.on_warning = true
  slack.on_failure = true

  # The integration token
  slack.webhook_url = 'my_webhook_url'

  ##
  # Optional
  #
  # The channel to which messages will be sent
  # slack.channel = 'my_channel'
  #
  # The username to display along with the notification
  # slack.username = 'my_username'
  #
  # The emoji icon to use for notifications.
  # See http://www.emoji-cheat-sheet.com for a list of icons.
  # slack.icon_emoji = ':ghost:'
  #
  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # slack.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

{% include markdown_links %}
