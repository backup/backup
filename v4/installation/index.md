---
layout: main
title: Installation
---

Installation
============

Backup v4.x is distributed using [RubyGems](https://rubygems.org) and supports
[Ruby](https://www.ruby-lang.org) versions `2.0.0+`,
`2.1.0+`, `2.2.0+` and `2.3.0+`.
Support for Ruby `2.4.0+` will be released in version 5, [try the
beta](https://rubygems.org/gems/backup). Version 5 also drops support for Ruby
`2.0`.

To install the latest version, run:

    $ gem install backup

This will install Backup, along with all of it's required dependencies.

See [Release Notes][release-notes] for changes in the latest version.

If you're upgrading from Backup v3.x, see [Upgrading][upgrading].

For Ruby versions `1.9.3`, support was dropped on version `4.1.11` so use an earlier version.
For Ruby versions `1.8.7` and `1.9.2`, please use [Backup v3.x][v3-overview].

### Using Bundler

**Do not add `gem backup` to another application's Gemfile.**
This means you **should not add Backup to a Rails** application's Gemfile.
Backup is not a _gem library_ and should not be treated as a _dependency_ of
another application. Bundler _can_ be used to manage an installation of Backup,
but the reasons for why you might want to do this is beyond the scope of this
document.

See also [this issue](https://github.com/meskyanichi/backup/issues/635) for
more information.

### Using sudo

The `gem` commands shown here may need to be run using `sudo`, depending on how Ruby is installed on your system. If
you're using [RVM][], [rbenv][] or [chruby][], then you would most likely _not_ want to use `sudo`. However, if your
installation of Ruby came with your system, or was installed using your system's package manager (yum, apt, etc...),
then you most likely need to use `sudo`. For example, running `gem install backup` as a non-root user with a system
installed Ruby would install Backup only for that user's use. This may or may not be what you want.

Updating
========

To update Backup to the latest version, run:

    $ gem install backup

Changes in the latest version may be found on the [Release Notes][release-notes] page.

If you wish to install a specific version of Backup, you can specify the version as follows:

    # Install version 4.1.0
    $ gem install backup -v '4.1.0'

    # Install the latest 4.1.x version
    $ gem install backup -v '~> 4.1.0'

    # Install the latest 4.x version
    $ gem install backup -v '~> 4.0'

When you update Backup, the new version of the Backup gem will be installed, but older versions are not removed.
If you were to install Backup at version `4.1.0`, then update to `4.2.0`, both will exist on your system.

    $ gem list backup

    *** LOCAL GEMS ***

    backup (4.1.0, 4.2.0)

The same is true for any of Backup's gem dependencies. This is normal and how the RubyGems system works.
When you run `backup` it will always load the latest version.

    $ backup version
    Backup 4.2.0

You can clean up old versions using `gem cleanup`.

    $ gem cleanup backup
    Cleaning up installed gems...
    Attempting to uninstall backup-4.1.0
    Successfully uninstalled backup-4.1.0
    Clean Up Complete

`gem cleanup` may be used to remove old versions of Backup's dependencies as well.


[RVM]: https://rvm.io/
[rbenv]: https://github.com/sstephenson/rbenv/
[chruby]: https://github.com/postmodern/chruby

{% include markdown_links %}
