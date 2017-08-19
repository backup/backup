---
layout: main
title: Notifier::HttpPost (Core)
---

Notifier::HttpPost (Core feature)
=================================

```rb
notify_by HttpPost do |post|
  post.on_success = true
  post.on_warning = true
  post.on_failure = true

  # URI to post the notification to.
  # Port may be specified if needed.
  # If Basic Authentication is required, supply user:pass.
  post.uri = 'https://user:pass@your.domain.com:8443/path'

  ##
  # Optional
  #
  # Additional headers to send.
  # post.headers = { 'Authentication' => 'my_auth_info' }
  #
  # Additional form params to post.
  # post.params = { 'auth_token' => 'my_token' }
  #
  # Successful response codes. Default: 200
  # post.success_codes = [200, 201, 204]
  #
  # Defaults to true on most systems.
  # Force with +true+, disable with +false+
  # post.ssl_verify_peer = false
  #
  # Supplied by default. Override with a custom 'cacert.pem' file.
  # post.ssl_ca_file = '/my/cacert.pem'
  #
  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # post.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

The `HttpPost` Notifier allows you to POST the result status of your backup to the URI of your choosing.

By default, the notifier will post the following parameters:

- `status`

  The value of `status` will be one of `success`, `warning` or `failure`.

- `message`

  If your backup model was defined as `Model.new(:my_backup, 'My Backup')`, then a success message
  would be `Backup::Success My Backup (my_backup)`. The `message` may be overridden in `params`. If set to
  `nil`, then the `message` parameter will not be sent.

Notifiers are retried if failures occur, and therefore `success_codes` should be set to the return codes
that would be acceptable for your POST. By default, only a return code of `200` will be considered successful.
Any other return code would cause Backup to retry sending the notification.

{% include markdown_links %}
