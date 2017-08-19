---
layout: main
title: Notifier::Nagios (Extra)
---

Notifier::Nagios (Extra)
========================

```rb
notify_by Nagios do |nagios|
  nagios.on_success = true
  nagios.on_warning = true
  nagios.on_failure = true

  nagios.nagios_host  = 'nagioshost'
  nagios.nagios_port  = 5667
  nagios.service_name = 'My Backup'
  nagios.service_host = 'backuphost'

  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # nagio.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

The Nagios Notifier allows you to send notifications to a central monitoring server running [Nagios](http://www.nagios.org/).
It uses the [NSCA][] (Nagios Service Check Acceptor) addon, available from the [Nagios SourceForge][] project page.
The Notifier sends `service_host`, `service_name`, the model's exit status code and a message to the `nagios_host`.

Model exit status codes are:

  - **0**: Successful
  - **1**: Successful with Warnings
  - **2**: Failed, but other triggers will be processed.
  - **3**: Failed, no other triggers will be processed.

[NSCA]: http://exchange.nagios.org/directory/Addons/Passive-Checks/NSCA--2D-Nagios-Service-Check-Acceptor/details
[Nagios SourceForge]: http://sourceforge.net/projects/nagios/files/

{% include markdown_links %}
