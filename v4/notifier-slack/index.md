---
layout: main
title: Notifier::Slack
---

Notifier::Slack
=================

``` rb
notify_by Slack do |slack|
  slack.on_success = true
  slack.on_warning = true
  slack.on_failure = true

  # The team name
  slack.team = 'my_team'

  # The integration token
  slack.token = 'xxxxxxxxxxxxxxxxxxxxxxxx'

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
end
```

{% include markdown_links %}
