---
layout: main
title: Preconfigured Models
---

Preconfigured Models
====================

If you have several Models that will always contain the same components,
you can preconfigure custom Models.

In your `config.rb`, _below your Component Defaults_:

```rb
preconfigure 'MyModel' do

  archive :user_pictures do |archive|
    archive.add '~/pictures'
  end

  notify_by Mail do |mail|
    mail.to = 'admin@email.com'
  end

end
```

You can now create multiple Models that will archive `~/pictures`, and notify you by mail.

```rb
MyModel.new(:john_smith, 'John Smith Backup') do

  archive :user_music do |archive|
    archive.add '~/music'
  end

  notify_by Mail do |mail|
    mail.to = 'john.smith@email.com'
  end

end
```
John Smith's backup will archive his `~/pictures` and `~/music` directories.  
It will then send a notification to both `admin@email.com` and `john.smith@email.com`.

```rb
MyModel.new(:mary_joe, 'Mary Joe Backup') do

  archive :user_documents do |archive|
    archive.add '~/documents'
  end

  notify_by Mail do |mail|
    mail.to = 'mary.joe@email.com'
  end

end
```
Mary Joe's backup will archive her `~/pictures` and `~/documents` directories.  
It will then send a notification to both `admin@email.com` and `mary.joe@email.com`.

It's important to understand that components you add within your Model will **add to** the preconfigured components.
There are a few exceptions:

- split_into_chunks_of
- encrypt_with
- compress_with
- before/after hooks

Any of these used within your Model definition will override a preconfigured setting.

{% include markdown_links %}
