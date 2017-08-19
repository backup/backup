---
layout: main
title: Notifier::Pagerduty (Extra)
---

Notifier::Pagerduty (Extra)
===========================

```rb
notify_by PagerDuty do |pagerduty|
  pagerduty.on_success = true
  pagerduty.on_warning = true
  pagerduty.on_failure = true

  pagerduty.service_key = '0123456789abcdef01234567890abcde'
  pagerduty.resolve_on_warning = true
end
```

This notifier opens an incident in PagerDuty when a backup model fails
or completes with a warning. A successful run will resolve an open
incident for that model.

Optionally, the notifier can be configured to resolve on a warning,
rather than triggering an incident. This might be wise when multiple
notifiers are in use (so warnings don't go unnoticed) and users want a
the next successful run to resolve the previously triggered incident.
