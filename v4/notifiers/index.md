---
layout: main
title: Notifiers
---

Notifiers
=========

Backup includes the following Notifiers:

- [Campfire][notifier-campfire] (Extra)
- [Datadog][notifier-datadog] (Extra)
- [Flowdock][notifier-flowdock] (Extra)
- [Hipchat][notifier-hipchat] (Extra)
- [HttpPost][notifier-httppost] (Core)
- [Mail][notifier-mail] (Core)
- [Nagios][notifier-nagios] (Extra)
- [Pagerduty][notifier-pagerduty] (Extra)
- [Prowl][notifier-prowl] (Extra)
- [Pushover][notifier-pushover] (Extra)
- [AWS SES][notifier-ses] (Core)
- [Slack][notifier-slack] (Core)
- [Twitter][notifier-twitter] (Extra)
- [Zabbix][notifier-zabbix] (Extra)


Notifier Failures
-----------------

By default, all notifiers are configured to retry failed attempts 10 times, pausing 30 seconds between each retry.
These defaults may be adjusted using `max_retries` and `retry_waitsec`.

```rb
notify_by Mail do |mail|
  mail.max_retries = 5
  mail.retry_waitsec = 60
end

# Or as defaults:
Notifier::Mail.defaults do |mail|
  mail.max_retries = 5
  mail.retry_waitsec = 60
end
```

All retry attempts will be logged. If a notifier exceeds `max_retries`, the failure will be logged.
Notifier failures will not cause your backup job to fail, or change the exit status of `backup perform`.

It's recommended that you setup at least one notifier to send `on_success` notifications.
If you only setup `on_failure` notifications, your backup and notifier could fail due to some network issue and you
would never know it.

{% include markdown_links %}
