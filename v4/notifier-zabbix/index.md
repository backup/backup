---
layout: main
title: Notifier::Zabbix (Extra)
---

Notifier::Zabbix (Extra)
========================

``` rb
notify_by Zabbix do |zabbix|
  zabbix.on_success = true
  zabbix.on_warning = true
  zabbix.on_failure = true

  zabbix.zabbix_host  = "zabbix_server_hostname"
  zabbix.zabbix_port  = 10051
  zabbix.service_name = "Backup trigger"
  zabbix.service_host = "zabbix_host"
  zabbix.item_key     = "backup_status"

  # Change default notifier message.
  # See https://github.com/backup/backup/pull/698 for more information.
  # zabbix.message = lambda do |model, data|
  #   "[#{data[:status][:message]}] #{model.label} (#{model.trigger})"
  # end
end
```
