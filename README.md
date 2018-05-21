# Backup

The new Backup.

Request For Change for the Ruby [Backup gem](https://github.com/backup/backup). This RFC describes a big overhaul of the Backup gem's backup pipeline in order to optimize its use of system resources.

Major changes are located in the pipeline and configuration as Ruby may not be a good fit for the new pipeline.

## Changelog

**Note**: All contents of this document are subject to change. Major changes will be documented here.

2018-05-19: Initial version.

## To discuss

- [Manager](#manager) implementation language
    - Ruby, Rust or something else?
- [Configuration](#configuration) file format?
  - YAML, JSON, TOML or something else?
- Decide upon first [component](#components) ([sources](#sources)) configuration.
  - Either STDIN or through a reference to the config or through arguments.
- Create a binary for every component type (e.g. backup-gzip) or directly call the gzip binary?
    - Calling the binary directly means the configuration logic must be in the manager.

## Overview

- [Motivation](#motivation)
- [Impact](#impact)
- [Pipeline](#pipeline)
- [Configuration](#configuration)
- [Components](#components)
    - [Manager](#manager)
    - [Sources](#sources)
    - [Compressors](#compressors)
    - [Encryptors](#encryptors)
    - [Storages](#storages)
    - [Notifiers](#notifiers)
    - [Hooks](#hooks)
    - [Custom commands](#custom-commands)

## Motivation

The current Backup pipeline is using a lot of host system resources when making a backup. Using the file system for temporary files storage for every part of the pipeline requires a lot of disk space and IO.

To speed up the backup process overhaul the pipeline to use UNIX pipes and stream data from component to component.

Configuration changes allow for more flexibility in configuring the pipeline, allowing users to add their own components without needing to modify the Backup gem's source code.

## Impact

The impact of this RFC is very high. The backup pipeline will be overhauled in such a way it's backwards incompatible with the current Ruby code.

The current Ruby gem implementation uses the local file system as a temporary storage system. This is inefficient and taxing on the host system. (For example having to store a 500GB backup locally before uploading it to AWS S3. The new pipeline will use UNIX pipes to stream data from component to component instead.  The local file system will not be used for temporary data storage of the pipeline.

It's also possible to move certain components away from the Ruby programming language to improve the performance and resource allocation of the backup process. It will continue to be possible to implement certain components in Ruby and even other languages.

The configuration will also have to change in order to allow for more configuration options in this pipeline, such as allowing any custom command to be run as part of the pipeline. This flexibility will allow users to make their own parts of the backup pipeline without having to modify the Backup tool to add support for their component.

The RFC also describes the components, their place in the pipeline and their responsibilities.

## Pipeline

The new Backup pipeline is a more efficient pipeline system that uses UNIX pipes. It streams data from [component](#components) to component without uses the file system. The upside to this is that it does not need large amounts of free space on the machine Backup is running on.

An example of the backup process using UNIX pipes in bash:

```
# Example using pipes
# backing up a database dump
pgdump ... | gz ... | openssl ... > backup.sql.gz

# or archiving files
tar ... | gz ... | openssl ... > backup.tar.gz

# sending it directly to AWS S3
tar ... | gz ... | openssl ... | backup_s3_uploader
```

The backup [manager](#manager) creates up this [pipeline](#pipeline) based on the user's config and performs the process. It keeps track of the backups that were made, where they're stored, how much space they take up, etc. It will also clean up any backups that are older than a specified date or total file size.

There are several components with different roles in this pipeline. [Sources](#sources) receive the configuration of the Backup model's sources as STDIN or a reference to the location of the configuration. It streams the source data to its STDOUT.

The components in the middle of the pipeline ([compressors](#compressors), [encryptors](#encryptors) and [custom commands](#custom-commands)) receive a stream of data to its STDIN as processed by the pipeline so far. It transforms the data in whatever way it's configured to do (compression, encryption, etc.). It continues the pipeline by streaming the new result to its STDOUT.

The end of the pipeline receives streams of data to its STDIN and sends it the storage option of choice. Preferably this storage option has streaming capabilities so it does not need to wait until the backup is complete before writing it to the source. It does not need to stream anything to its STDOUT. The backup pipeline ends here.

## Configuration

The configuration would change from the existing implementation. Currently it's using a Ruby DSL which is unintuitive for non-Ruby developers. Using a different configuration format we can hide the implementation language of Ruby and make it more accessible. When overhauling the config we should aim for a more consistent definition format.

```
/etc/backup/conf/my_model.yml
```

It would also be possible for the configuration to be dynamically created by calling a binary that returns the config in the decided upon format upon executing it.

```
$ ruby generate_backup_config.rb
# Prints configuration as STDOUT
```

### Definition

**Note**: Definition described in YAML, format may change in the future.

Each component of Backup has its own configuration section with its own options that can be configured. Components follow the same basic format, but can differ to configure multiple executions of the component.

Single component configuration:

```yml
component_section:
  component: component_name
    options:
      username: root
      password: secret
```

Multi-component configuration:

```yml
component_section:
  - component: component_name
    options:
      username: root
      password: secret
  - component: other_component_name
    options:
      client_id: abcdefg1234
      secret_key: secret
```

#### Example

```yml
# /etc/backup/conf/my_model.yml

# Configuration of Backup itself
database: # TODO: Should be configurable?
  path: "/etc/backup/db/backup_$BACKUP_MODEL_NAME-$BACKUP_TIMESTAMP.json"

log: # TODO: Should be configurable?
  path: "/var/log/backup_$BACKUP_MODEL_NAME.log"

# Hooks to be executed before and after a backup
hooks:
  before:
    - command: ruby some_before_script.rb
      env:
        ENV_VAR_1: some_value
        ENV_VAR_2: other_value
        ENV_VAR_3: $BACKUP_MODEL_NAME
      arguments:
        - "--quiet"
        - "some_arg"
        - "$BACKUP_MODEL_NAME"
  after:
    - command: ruby some_before_script.rb
      on_success: true
      on_failure: false
      env:
        ENV_VAR_1: some_value
        ENV_VAR_2: other_value
        ENV_VAR_3: $BACKUP_MODEL_NAME
      arguments:
        - foo
        - bar
        - $BACKUP_MODEL_NAME

# Backup model configuration
cycle:
  days: 7 # integer
  amount: 100 # number of backups
  size: 1024 # in bytes

sources:
  - component: fs # Looks for `backup_fs` executable in $PATH
    name: "my_archive" # Used for backup file naming
    options: # Options used by backup_fs to configure the archive utility
      include:
        - /path/to/my/archive
        - /path/to/other/archive
      exclude:
        - /path/to/my/sensitive/data
  - component: postgresql
    name: "my_database_dump" # Used for backup file naming
    options: # Options used by backup_postgesql to configure the pg_dump utility
      host: localhost
      database: my_database_production
      username: root
      password: password
  - component: command
    name: "my_custom_source" # Used for backup file naming
    command: "ruby my_dump_script.rb"
    env:
      ENV_VAR_1: some_value
      ENV_VAR_2: other_value
      ENV_VAR_3: $BACKUP_MODEL_NAME
    arguments: # Custom arguments for the command
      - foo
      - bar
      - $BACKUP_MODEL_NAME

compressor:
  component: gzip
  options:
    level: 5

encryptor:
  component: openssl
  options:
    password: my_password

storage:
  - component: fs
    options:
      path: /path/to/backup
      exclude:
        - /path/to/backup/tmp
  - component: aws_s3
    options:
      access_key_id: my_access_key_id
      secret_access_key: my_secret_access_key
      region: eu-west-1
      bucket: my_backups_bucket
      path: backups/

notifiers:
  - component: email
    on_success: false
    on_failure: true
    options:
      domain: my.domain.com
      user: root
      password: password
      from: backups@domain.com
      to: me@domain.com
      subject: "Backup %model% %status_verb%!"
```

## Components

- [Manager](#manager)
- [Sources](#sources)
- [Compressors](#compressors)
- [Encryptors](#encryptors)
- [Storages](#storages)
- [Notifiers](#notifiers)
- [Hooks](#hooks)

### Manager

The manager is responsible for creating the backup pipeline and removing previous backups that were made when they are past a certain age or total file size. The user configure the manager which sends the configuration to the separate [components](#components).

Responsibilities:
- Creating and executing the backup pipeline.
- Removing old backups past a certain age or total file size.

Not Backup's responsibilities:
- Scheduling
    - Backup is not responsible for scheduling backups. This should be set up with tools like cron instead.

### Sources

Sources are locations Backup can fetch data from to backup. These can be from the file system, database, external servers, etc.

List of possible sources:

- Local file system: archives
- Databases (MySQL, PostgreSQL, MongoDB, Redis, etc.)
- External servers
- Remote git repos
- etc.

```yml
sources:
  - component: fs
    options:
      path: /path/to/backup
      exclude:
        - /path/to/backup/tmp
  - component: aws_s3
    options:
      access_key_id: my_access_key_id
      secret_access_key: my_secret_access_key
      region: eu-west-1
      bucket: my_backups_bucket
      path: backups/
```

More than one source can be configured per Backup model.

### Compressors

Methods of compressing backup files to reduce their size on the [storage](#storages).

List of possible compressors:

- gzip
- bzip2
- lzma
- etc.

```yml
compressor:
  component: gzip
  options:
    level: 5
```

Only one compressor should be configured per Backup model.

### Encryptors

Methods to encrypt backups files and secure them with a passphrase or other authentication methods.

List of possible encryptors:

- OpenSSL
- GPG
- etc.

```yml
encryptor:
  component: openssl
  options:
  password: my_password
```

Only one encryptor should be configured per Backup model.

### Storages

Storages are locations the backup file will be stored on after the whole backup pipeline has been completed.

List of possible storage options:

- Local file system
- AWS S3
- AWS Glacier
- etc.

```yml
storage:
  - component: fs
    options:
      path: /path/to/backup
      exclude:
        - /path/to/backup/tmp
  - component: aws_s3
    options:
      access_key_id: my_access_key_id
      secret_access_key: my_secret_access_key
      region: eu-west-1
      bucket: my_backups_bucket
      path: backups/
```

More than one storage can be configured per Backup model.

### Notifiers

Notifiers are used to inform the user about the result of their backups. It can be configured to notify on success, failure or both.

List of possible notifiers:

- Email
- Pagerduty
- Slack
- etc.

```yml
notifiers:
  - component: email
    on_success: false
    on_failure: true
    options:
      domain: my.domain.com
      user: root
      password: password
      from: backups@domain.com
      to: me@domain.com
      subject: "Backup %model% %status_verb%!"
```

More than one notifier can be configured per Backup model.

### Hooks

Custom steps to perform before or after a backup is made. Before hooks will always run if the configuration is valid. After hooks can be configured to run on a successful backup, on failure or always.

As we don't know what users will use these hooks for exactly they should be customizable, letting the users do whatever they need it to.

```yml
hooks:
  before:
    - command: ruby some_before_script.rb
      env:
        ENV_VAR_1: some_value
        ENV_VAR_2: other_value
        ENV_VAR_3: $BACKUP_MODEL_NAME
      arguments:
        - foo
        - bar
        - $BACKUP_MODEL_NAME
```

### Custom commands

Configuring a command on any component will trigger a call to the configured executable to be part of the pipeline. When a command is configured for a hook it will receive the configuration data of the Backup model so it can perform actions before or after the backup is made.

```yml
source:
  - component: command
    name: "my_custom_source" # Used for file naming
    command: "ruby my_dump_script.rb"
    env:
      ENV_VAR_1: some_value
      ENV_VAR_2: other_value
      ENV_VAR_3: $BACKUP_MODEL_NAME
    arguments:
      - foo
      - bar
      - $BACKUP_MODEL_NAME

compressor:
  component: command
  command: "bash"
  env:
    ENV_VAR_1: some_value
    ENV_VAR_2: other_value
    ENV_VAR_3: $BACKUP_MODEL_NAME
  arguments:
    - "my_custom_compressor.sh"
    - "--compress-level=9000"
    - "--crash-on-failure"
```

For hooks:

```yml
hooks:
  before:
    - command: ruby some_before_script.rb
      env:
        ENV_VAR_1: some_value
        ENV_VAR_2: other_value
        ENV_VAR_3: $BACKUP_MODEL_NAME
      arguments:
        - foo
        - bar
        - $BACKUP_MODEL_NAME
```
