---
layout: main
title: Notifier::Datadog (Extra)
---

Notifier::DataDog (Extra)
=========================

``` rb
notify_by DataDog do |datadog|
  datadog.on_success           = true
  datadog.on_warning           = true
  datadog.on_failure           = true

  datadog.api_key              = 'my_api_key'

  ##
  # Optional
  #
  # Override Default Title
  # Default is: "Backup #{:label}"
  # datadog.title                = "Backup #{:status}"
  #
  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # datadog.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
  #
  # Provide a hostname to associate this backup to
  # Default is nil
  # datadog.host                 = 'db.example.com'
  #
  # Add Tags to the Event
  # Default is nil
  # valid option is an Array
  # datadog.tags                 = ['backup', 'env:production']
  #
  # Override the Alert Type
  # Default is based on the :status of the backup:
  # :success => 'success'
  # :warning => 'warning'
  # :failure => 'error'
  # valid options are: 'info', 'success', 'warning', 'error'
  # datadog.alert_type           = 'info'
  #
  # Add a Source Type
  # Default is nil
  # see api docs for valid source_type_names
  # datadog.source_type_name        = 'my apps'
  #
  # Override the Priority Level
  # Default is 'normal'
  # valid options are: 'normal' or 'low'
  # datadog.priority             = 'low'
  #
  # Override the Event Time (must be a unix Timestamp)
  # Default is Time.now.to_i
  # datadog.date_happened        = Time.now.to_i
  #
  # Add an Aggregation Key
  # Default is nil
  # max length allowed is 100 characters
  # datadog.aggregation_key      = 'my_aggregation'
end
```

{% include markdown_links %}
