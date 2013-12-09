---
layout: main
title: Scheduling Backups
---

Scheduling Backups
==================

Simple. Just use a cron task to invoke the Backup CLI.  

I recommend you use [Whenever][1], a Ruby Gem that allows you to write elegant syntax for managing the crontab.

Example
-------

- Generate a `schedule.rb` file with the Whenever gem

```
$ mkdir config # Whenever assumes a `config` directory exists
$ wheneverize
~ [add] writing './config/schedule.rb'
~ [done] wheneverized!
```

- Open the `config/schedule.rb` file and add the following:

``` rb
every 1.day, :at => '4:30 am' do
  command "backup perform -t my_backup"
end
```

- Run `whenever` with no arguments see the `crontab` entry this will create

```
$ whenever
~ 30 4 * * * /bin/bash -l -c 'backup perform -t my_backup'
~
~ ## [message] Above is your schedule file converted to cron syntax; your crontab file was not updated.
~ ## [message] Run 'whenever --help' for more options.
```

- To write (or update) this job in your `crontab`, use:

```
$ whenever --update-crontab
~ [write] crontab file written

$ crontab -l # to view the crontab entry
~ # Begin Whenever generated tasks for: /absolute/path/to/config/schedule.rb
~ 30 4 * * * /bin/bash -l -c 'backup perform -t my_backup'
~
~  
~ # End Whenever generated tasks for: /absolute/path/to/config/schedule.rb
```

Note that Whenever uses the absolute path to the `schedule.rb` file as an _identifier_ for this file's entries in your
`crontab`. If you wish to specify an _identifier_, use the `-f` option to specify the `schedule.rb` file, then use the
`-w` (write/update) or `-c` (clear) options and specify the _identifier_.

So, to continue with this example...

- Remove the `crontab` entry which you just added and replace it with one specifying the _identifier_

```
$ whenever --clear-crontab
~ [write] crontab file

$ whenever -f config/schedule.rb -w 'my backup'
~ [write] crontab file

$ crontab -l
~ # Begin Whenever generated tasks for: my backup
~ 30 4 * * * /bin/bash -l -c 'backup perform -t my_backup'
~
~
~ # End Whenever generated tasks for: my backup
```

This simply provides for a more readable crontab. And, if you're managing multiple backup jobs, you can use
the `-f` option and keep all your Whenever files in one place, each named after the backup it schedules.

Check out the Whenever gem's [README][1] and [Wiki][2] for more information.

[1]: https://github.com/javan/whenever
[2]: https://github.com/javan/whenever/wiki

{% include markdown_links %}
