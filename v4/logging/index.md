---
layout: main
title: Logging
---

Logging
=======

Backup supports 3 different methods of logging messages during the backup process.

- **Console**: Sending messages directly to the console. (Core)
- **Logfile**: Storing all messages within Backup's own `backup.log` file. (Core)
- **Syslog**: Sending messages to the system's Syslog compatible logger. (Extra)

Each of these methods may be enabled/disabled via command line options, or within your `config.rb` file.

```ruby
# Shown here with their default values
Logger.configure do
  # Console options:
  console.quiet = false

  # Logfile options:
  logfile.enabled   = true
  logfile.log_path  = 'log'
  logfile.max_bytes = 500_000

  # Syslog options:
  syslog.enabled  = false
  syslog.ident    = 'backup'
  syslog.options  = Syslog::LOG_PID
  syslog.facility = Syslog::LOG_LOCAL0
  syslog.info     = Syslog::LOG_INFO
  syslog.warn     = Syslog::LOG_WARNING
  syslog.error    = Syslog::LOG_ERR
end
```

Console Options
---------------

```ruby
Logger.configure do
  console.quiet = true
end
```

#### console.quiet

Setting this to `true` is equivalent to using `--quiet` on the command line.

Using `--no-quiet` on the command line would override this setting in `config.rb`.

Messages of type `:info` are sent on `STDOUT`. Messages of type `:warn` and `:error` are sent on `STDERR`.


Logfile Options
---------------

```ruby
Logger.configure do
  logfile.enabled   = true
  logfile.log_path  = 'log'
  logfile.max_bytes = 500_000
end
```

#### logfile.enabled

Setting this to `true` is equivalent to using `--logfile` on the command line.
This is `true` by default, so the use of `--logfile` on the command line is not necessary.

Setting this to `false` will disable the use of Backup's `backup.log` file.
This may also be accomplished using the `--no-logfile` command line switch.

Use of `--no-logfile` on the command line would override a setting of `true` in the `config.rb`.

When disabled, `--log-path` will not be used or created.

#### logfile.log_path

Setting this is equivalent to using the `--log-path` command line option.

This may be set to an absolute path, or a path relative to `--root-path`.
By default, this is set to `'log'`, which would be `~/Backup/log` if using the default `--root-path`.

If a path is specified using the `--log-path` command line option, any setting here will be ignored.

#### logfile.max_bytes

Before each `backup perform` command is run, the `backup.log` file will be truncated,
leaving only the most recent entries. By default, `max_bytes` is set to `500K`.

Note that truncation only occurs once before all models matching the given trigger(s) are performed.

**Note:** If you plan to run triggers using a non-root user AND the root user (or via sudo),
and `--log_path` will be the same for these jobs, be sure to run the first job with the non-root user
so the log file won't be initially created with root-only write access.


Syslog Options
--------------

```ruby
Logger.configure do
  syslog.enabled  = false
  syslog.ident    = 'backup'
  syslog.options  = Syslog::LOG_PID
  syslog.facility = Syslog::LOG_LOCAL0
  syslog.info     = Syslog::LOG_INFO
  syslog.warn     = Syslog::LOG_WARNING
  syslog.error    = Syslog::LOG_ERR
end
```

#### syslog.enabled

Setting this is equivalent to using the `--syslog` command line option. This is `false` by default.

Use of the `--no-syslog` command line option will override any setting in `config.rb`.

**Note:** Messages sent to Syslog are sent without a timestamp or severity level within the message text,
since Syslog will provide these.

For example, messages logged to the `Console` or `Logfile` will be sent as:

    [YYYY/MM/DD HH:MM:SS][level] message line text

Whereas messages sent to `Syslog` will simply be sent as:

    message line text


#### syslog.ident

By default, this is set to `'backup'`.

Be sure to check with your logger's documentation for any restrictions.

**syslog.options**

By default this is set to `Syslog::LOG_PID`.

Note that setting this to `nil` would cause [Syslog][] to default to `LOG_PID | LOG_CONS`.

See the [Syslog.open][] documentation for acceptable values.

#### syslog.facility

By default this is set to `Syslog::LOG_LOCAL0`.

Note that setting this to `nil` would cause [Syslog][] to default to `LOG_USER`.

See the [Syslog.open][] documentation for acceptable values.

#### syslog.info, syslog.warn, syslog.error

By default, these are set to `Syslog::LOG_INFO`, `Syslog::LOG_WARNING` and `Syslog::LOG_ERR`.

See the [Syslog.log][] documentation for acceptable values.


Ignoring Warnings
-----------------

Whenever Backup's Logger receives `:warn` level messages, this will cause Backup to send `on_warning`
[Notifications][notifiers] and report the backup as having "Completed (with Warnings)". If you're receiving warning
messages that can't be avoided for some reason, you can configure Backup's Logger to ignore these messages.

```rb
Logger.configure do
  ignore_warning 'that contains this string'
  ignore_warning /that matches this regexp/
end
```

Any `:warn` level messages that match will be downgraded to `:info` level messages.


[Performing Backups]: Performing-Backups
[Syslog]: http://rdoc.info/stdlib/syslog/Syslog
[Syslog.open]: http://rdoc.info/stdlib/syslog/Syslog.open
[Syslog.log]: http://rdoc.info/stdlib/syslog/Syslog.log

{% include markdown_links %}
