Backup
======

[![Code Climate](https://codeclimate.com/github/backup/backup.svg)](https://codeclimate.com/github/backup/backup)
[![Build Status](https://github.com/backup/backup/actions/workflows/rspec.yml/badge.svg)](https://github.com/backup/backup/actions/workflows/rspec.yml)
[![Join the chat at https://gitter.im/backup/backup](https://badges.gitter.im/Join%20Chat.svg)][Gitter]

> This project is welcoming new contributors and maintainers. See CONTRIBUTING.md

Backup is a system utility for Linux and Mac OS X, distributed as a RubyGem, that allows you to easily perform backup
operations. It provides an elegant DSL in Ruby for _modeling_ your backups. Backup has built-in support for various
databases, storage protocols/services, syncers, compressors, encryptors and notifiers which you can mix and match. It
was built with modularity, extensibility and simplicity in mind.

[Installation][] &middot; [Release Notes][] &middot; [Documentation][] &middot; [Issues][] &middot;  [Chat][Gitter]

## Installing a repository build on Ubuntu 24.04

The repository is packaged as a RubyGem before it is installed. From the
repository directory on the host Mac, build the gem:

```sh
gem build backup.gemspec
```

This creates `backup-5.0.0.beta.3.gem` (the filename follows the version in
`lib/backup/version.rb`). Start a persistent Ubuntu 24.04 test container and
copy that file into it:

```sh
container run --detach --name backup-ubuntu2404 --memory 4G ubuntu:24.04 sleep infinity
container cp backup-5.0.0.beta.3.gem backup-ubuntu2404:/tmp/backup.gem
```

Install Ubuntu's Ruby and compiler packages, then install and verify the local
gem. `build-essential` is required by a legacy notifier dependency that still
contains a native extension.

```sh
container exec backup-ubuntu2404 apt-get update
container exec backup-ubuntu2404 apt-get install -y ruby-full build-essential
container exec backup-ubuntu2404 gem install /tmp/backup.gem --no-document
container exec backup-ubuntu2404 backup version
```

Rebuild and copy the gem again after changing the repository. Use a new clean
container when validating installation dependencies, since an existing
container may retain packages or gems from an earlier attempt.

## Project Status: Looking for contributors and maintainers ##

This project is not under active development, although we will continue to provide support for current users, but you can change that by joining the team (see CONTRIBUTING.md)

If you use this project and would like to develop it further, please introduce yourself on the [maintainers wanted][Maintainers wanted] ticket.

**Copyright (c) 2009-2017 [Michael van Rooijen][] ( [@mrrooijen] )**
Released under the **MIT** [LICENSE](LICENSE).

[Installation]:  http://backup.github.io/backup/v4/installation
[Release Notes]: http://backup.github.io/backup/v4/release-notes
[Documentation]: http://backup.github.io/backup/v4
[Issues]: https://github.com/backup/backup/issues
[Gitter]: https://gitter.im/backup/backup?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge
[Maintainers wanted]: https://github.com/backup/backup/issues/803
[Michael van Rooijen]: http://github.com/mrrooijen
[@mrrooijen]: http://twitter.com/mrrooijen
