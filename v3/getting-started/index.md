---
layout: main
title: Getting Started
---

Getting Started
===============

The following is a simple walk-through to familiarize you with how Backup works.

If you have not yet installed Backup, see the [Installation][installation] page.

Generating Your First Backup Model
----------------------------------

Let's generate a simple Backup model file:

    $ backup generate:model --trigger my_backup \
      --archives --storages='local' --compressors='gzip' --notifiers='mail'

(For a full list of options, view the [Generator][generator] Page)

The above generator will provide us with a backup model file (located in `~/Backup/models/my_backup.rb`) that looks like this:

```rb
##
# Backup Generated: my_backup
# Once configured, you can run the backup with the following command:
#
# $ backup perform -t my_backup [-c <path_to_configuration_file>]
#
Model.new(:my_backup, 'Description for my_backup') do
  ##
  # Split [Splitter]
  #
  # Split the backup file in to chunks of 250 megabytes
  # if the backup file size exceeds 250 megabytes
  #
  split_into_chunks_of 250

  ##
  # Archive [Archive]
  #
  # Adding a file:
  #   archive.add "/path/to/a/file.rb"
  #
  # Adding an directory (including sub-directories):
  #   archive.add "/path/to/a/directory/"
  #
  # Excluding a file:
  #   archive.exclude "/path/to/an/excluded_file.rb"
  #
  # Excluding a directory (including sub-directories):
  #   archive.exclude "/path/to/an/excluded_directory/
  #
  archive :my_archive do |archive|
    archive.add "/path/to/a/file.rb"
    archive.add "/path/to/a/folder/"
    archive.exclude "/path/to/a/excluded_file.rb"
    archive.exclude "/path/to/a/excluded_folder/"
  end

  ##
  # Local (Copy) [Storage]
  #
  store_with Local do |local|
    local.path       = "~/backups/"
    local.keep       = 5
  end

  ##
  # Gzip [Compressor]
  #
  compress_with Gzip

  ##
  # Mail [Notifier]
  #
  # The default delivery method for Mail Notifiers is 'SMTP'.
  # See the Wiki for other delivery options.
  # https://github.com/meskyanichi/backup/wiki/Notifiers
  #
  notify_by Mail do |mail|
    mail.on_success           = true
    mail.on_warning           = true
    mail.on_failure           = true

    mail.from                 = "sender@email.com"
    mail.to                   = "receiver@email.com"
    mail.address              = "smtp.gmail.com"
    mail.port                 = 587
    mail.domain               = "your.host.name"
    mail.user_name            = "sender@email.com"
    mail.password             = "my_password"
    mail.authentication       = "plain"
    mail.encryption           = :starttls
  end

end
```

You will also notice, this generated a `~/Backup/config.rb` file. This is Backup's main configuration file.
When Backup is run, this is the first file that is loaded. Here you may setup any global configuration needed, as well
as setup any component defaults. This file will then load all your _model_ files in `~/Backup/models`.
See the [Generator][generator] page for details.


Configuring the Backup Model
----------------------------

In order to perform this sample backup job, you'll need to update the generated model file.

- Update the `Archive` section to add a folder containing some files to backup.

- Update the `Storage` section and set the path to a folder to store the backup. This path will be created if it
doesn't exist.

- Update the `Notifier` with proper credentials. If you do not wish to setup the `Notifier` credentials at this time,
  you can omit it.

Once you've setup your configuration, check your work with:

    $ backup check

If there are no syntax errors, the check should report:

    [info] Configuration Check Succeeded.

More information about the `check` command can be found on [Performing Backups][performing-backups] page.


Performing Your First Backup
----------------------------

Now that you've setup your model, you can run this backup by issuing the following command:

    $ backup perform --trigger my_backup

The `my_backup` refers to the `:my_backup` symbol in:

``` rb
Model.new(:my_backup, 'Description for my_backup') do
```

When completed, you will find your backup in the `Storage` path you specified. There you will find a folder named after
the `trigger` you provided. Within this folder, a timestamped folder will exist for each backup job performed. In these
folders, a `tar` file will exist named `<trigger>.tar`. This `tar` file is a _package_ that will contain all the
Archives and Databases configured for the model (trigger).


This has been a very simple walk-through, but you should now have a general idea of how to setup, configure and perform
a backup job.

{% include markdown_links %}
