---
layout: main
title: Component Defaults
---

Component Defaults
==================

The following Model components may have default values set:

  - Databases - `Database::MySQL`, etc...
  - Compressors - `Compressor::Gzip`, etc...
  - Encryptors - `Encryptor::GPG`, etc...
  - Storages - `Storage::S3`, etc...
  - Syncers - `Syncer::Cloud::S3`, `Syncer::RSync::Push`, etc...
  - Notifiers - `Notifier::Mail`, etc...

For example, in your `config.rb`:

``` rb
Notifier::Mail.defaults do |mail|
  mail.from                 = 'sender@email.com'
  mail.to                   = 'receiver@email.com'
  mail.address              = 'smtp.gmail.com'
  mail.port                 = 587
  mail.domain               = 'your.host.name'
  mail.user_name            = 'sender@email.com'
  mail.password             = 'my_password'
  mail.authentication       = 'plain'
  mail.encryption           = :starttls
end
```

This allows you to add these components to any Model, with some or all options already set.

```rb
Model.new(:john_smith, 'John Smith Backup') do

  archive :user_music do |archive|
    archive.add '~/music'
  end

  # this will notify using the default settings
  notify_by Mail

  # this will use the defaults, except for the new recipient
  notify_by Mail do |mail|
    mail.to = 'john.smith@email.com'
  end

end
```

Any value you specify when defining your Model will override default values.

_Note that some components have settings that can not have default values._


{% include markdown_links %}
