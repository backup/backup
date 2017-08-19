---
layout: main
title: Notifier::Ses (Core)
---

Notifier::Ses (Core feature)
============================

[AWS SES](http://aws.amazon.com/ses/)

``` rb
notify_by Ses do |ses|
  ses.on_success = true
  ses.on_warning = true
  ses.on_failure = true

  ses.access_key_id = ''
  ses.secret_access_key = ''
  ses.region = 'eu-west-1'

  ses.from = "sender@email.com"
  ses.to = "receiver@email.com"
  ses.cc = "cc@email.com"
  ses.bcc = "bcc@email.com"
  ses.reply_to = "reply_to@email.com"

  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # ses.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

{% include markdown_links %}
