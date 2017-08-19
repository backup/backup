---
layout: main
title: Notifier::Mail (Core)
---

Notifier::Mail (Core feature)
=============================

``` rb
notify_by Mail do |mail|
  mail.on_success           = true
  mail.on_warning           = true
  mail.on_failure           = true

  # For information on the types of these attributes, see the Mail gem documentation.
  # http://www.rubydoc.info/github/mikel/mail/Mail/Message
  mail.from                 = 'sender@email.com'
  mail.to                   = 'receiver@email.com'
  mail.cc                   = 'cc@email.com'
  mail.bcc                  = 'bcc@email.com'
  mail.reply_to             = 'reply_to@email.com'
  mail.address              = 'smtp.gmail.com'
  mail.port                 = 587
  mail.domain               = 'your.host.name'
  mail.user_name            = 'sender@email.com'
  mail.password             = 'my_password'
  mail.authentication       = 'plain'
  mail.encryption           = :starttls

  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # mail.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

This will make `sender@email.com` send an email to `receiver@email.com` every time a Backup process ends.

To receive an email only if a problem occurs, use:

``` rb
  mail.on_success           = false
  mail.on_warning           = true
  mail.on_failure           = true
```

`on_warning` notifications are sent when warnings occur, but the backup process was still successful.
`on_success` implies `on_warning`. If `on_success` is `true`, then warning notifications will be sent regardless of the
setting of `on_warning`.

To ignore warnings and only receive an email if the backup process fails, use:

``` rb
  mail.on_success           = false
  mail.on_warning           = false
  mail.on_failure           = true
```

### Attached Log File

By default, `on_warning` and `on_failure` notifications will have a copy of Backup's log file attached. If you wish to
have the log file attached to `on_success` notifications, or not attached to others, you can configure this using
`send_log_on`.

```rb
  mail.send_log_on = [:warning, :failure] # default setting
  mail.send_log_on = [:success, :warning, :failure] # attach to all notifications
  mail.send_log_on = [] # attach to none
```

### SMTP Connection Security

`mail.encryption` is set to `:starttls` by default, which will use `STARTTLS` to upgrade the initial connection to
`SSL/TLS`. It may also be set to `:ssl` (or `:tls`) to initiate a direct `SSL/TLS` connection.
For no encryption, set to `:none`.


### Other Delivery Methods


The Mail Notifier uses the [Mail][] library. Mail notifications are sent using [Mail::SMTP][] by default,
but the [Mail::Sendmail][], [Mail::Exim][] and [Mail::FileDelivery][] delivery methods are also supported.

* To use [Mail::Sendmail][], use the following:

``` rb
notify_by Mail do |mail|
  mail.on_success           = true
  mail.on_warning           = true
  mail.on_failure           = true

  mail.delivery_method      = :sendmail
  mail.from                 = 'sender@email.com'
  mail.to                   = 'receiver@email.com'

  # optional settings:
  mail.sendmail_args        # string of arguments to to pass to `sendmail`
end
```

**Note:** `sendmail_args` will _override_ the defaults set by [Mail::Sendmail][].
See the source for [Mail::Sendmail:initialize][] for details.

* To use [Mail::Exim][], use the following:

``` rb
notify_by Mail do |mail|
  mail.on_success           = true
  mail.on_warning           = true
  mail.on_failure           = true

  mail.delivery_method      = :exim
  mail.from                 = 'sender@email.com'
  mail.to                   = 'receiver@email.com'

  # optional settings:
  mail.exim_args            # string of arguments to to pass to `exim`
end
```

**Note:** `exim_args` will _override_ the defaults set by [Mail::Exim][].
See the source for [Mail::Sendmail:initialize][] for details,
as [Mail::Exim][] inherits it's constructor from [Mail::Sendmail][].

* To use [Mail::FileDelivery][], use the following:

``` rb
notify_by Mail do |mail|
  mail.on_success           = true
  mail.on_warning           = true
  mail.on_failure           = true

  mail.delivery_method      = :file
  mail.from                 = 'sender@email.com'
  mail.to                   = 'receiver@email.com'
  mail.mail_folder          = '/path/to/store/emails' # default: ~/Backup/emails
end
```

[Mail]: http://rubydoc.info/gems/mail/frames
[Mail::SMTP]: http://rubydoc.info/gems/mail/Mail/SMTP
[Mail::Sendmail]: http://rubydoc.info/gems/mail/Mail/Sendmail
[Mail::Exim]: http://rubydoc.info/gems/mail/Mail/Exim
[Mail::FileDelivery]: http://rubydoc.info/gems/mail/Mail/FileDelivery
[Mail::Sendmail:initialize]: http://rubydoc.info/gems/mail/Mail/Sendmail:initialize

{% include markdown_links %}
