---
layout: main
title: Notifier::Twitter (Extra)
---

Notifier::Twitter (Extra)
=========================

``` rb
notify_by Twitter do |tweet|
  tweet.on_success = true
  tweet.on_warning = true
  tweet.on_failure = true

  tweet.consumer_key       = 'my_consumer_key'
  tweet.consumer_secret    = 'my_consumer_secret'
  tweet.oauth_token        = 'my_oauth_token'
  tweet.oauth_token_secret = 'my_oauth_token_secret'

  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # twitter.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

In order to use [Twitter](http://twitter.com/) as a notifier you will need a Twitter account.
Once you create a Twitter account for the notifier,
you need to [register a new application](http://dev.twitter.com/apps) for your Twitter account.
After registering an application you will acquire the following credentials:

* `consumer_key`
* `my_consumer_secret`
* `my_oauth_token`
* `my_oauth_token_secret`

You can find these credentials on your application's pages.

{% include markdown_links %}
