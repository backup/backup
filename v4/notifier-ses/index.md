---
layout: main
title: Notifier::Ses
---

Notifier::Ses
=================

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
end
```

{% include markdown_links %}
