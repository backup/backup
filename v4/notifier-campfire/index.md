---
layout: main
title: Notifier::Campfire (Extra)
---

Notifier::Campfire (Extra)
==========================

``` rb
notify_by Campfire do |campfire|
  campfire.on_success = true
  campfire.on_warning = true
  campfire.on_failure = true

  campfire.api_token = 'my_token'
  campfire.subdomain = 'my_subdomain'
  campfire.room_id   = 'the_room_id'

  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # campfire.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```

In order to use [Campfire](http://campfirenow.com/) as a notifier you will need a Campfire account.
Once you create a Campfire account for the notifier, you need to create a room and take note of its id (*room_id*)
(https://<your-subdomain>.campfirenow.com/room/<room_id>), get your *api authentication token* from the "My info" page,
and take note of your *subdomain* (https://<your-subdomain>.campfirenow.com/).


{% include markdown_links %}
