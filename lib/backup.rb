# encoding: utf-8

# Load Ruby Core Libraries
require 'rubygems'
require 'fileutils'
require 'tempfile'
require 'yaml'
require 'etc'

require 'open4'
require 'thor'

##
# The Backup Ruby Gem
module Backup

  ##
  # Backup's internal paths
  LIBRARY_PATH       = File.join(File.dirname(__FILE__), 'backup')
  CLI_PATH           = File.join(LIBRARY_PATH, 'cli')
  STORAGE_PATH       = File.join(LIBRARY_PATH, 'storage')
  DATABASE_PATH      = File.join(LIBRARY_PATH, 'database')
  COMPRESSOR_PATH    = File.join(LIBRARY_PATH, 'compressor')
  ENCRYPTOR_PATH     = File.join(LIBRARY_PATH, 'encryptor')
  NOTIFIER_PATH      = File.join(LIBRARY_PATH, 'notifier')
  SYNCER_PATH        = File.join(LIBRARY_PATH, 'syncer')
  TEMPLATE_PATH      = File.expand_path('../../templates', __FILE__)

  ##
  # Autoload Backup CLI files
  module CLI
    autoload :Helpers, File.join(CLI_PATH, 'helpers')
    autoload :Utility, File.join(CLI_PATH, 'utility')
  end

  ##
  # Autoload Backup storage files
  module Storage
    autoload :Base,       File.join(STORAGE_PATH, 'base')
    autoload :Cycler,     File.join(STORAGE_PATH, 'cycler')
    autoload :S3,         File.join(STORAGE_PATH, 's3')
    autoload :CloudFiles, File.join(STORAGE_PATH, 'cloudfiles')
    autoload :Ninefold,   File.join(STORAGE_PATH, 'ninefold')
    autoload :Dropbox,    File.join(STORAGE_PATH, 'dropbox')
    autoload :FTP,        File.join(STORAGE_PATH, 'ftp')
    autoload :SFTP,       File.join(STORAGE_PATH, 'sftp')
    autoload :SCP,        File.join(STORAGE_PATH, 'scp')
    autoload :RSync,      File.join(STORAGE_PATH, 'rsync')
    autoload :Local,      File.join(STORAGE_PATH, 'local')
  end

  ##
  # Autoload Backup syncer files
  module Syncer
    autoload :Base, File.join(SYNCER_PATH, 'base')
    module Cloud
      autoload :Base,       File.join(SYNCER_PATH, 'cloud', 'base')
      autoload :CloudFiles, File.join(SYNCER_PATH, 'cloud', 'cloud_files')
      autoload :S3,         File.join(SYNCER_PATH, 'cloud', 's3')
    end
    module RSync
      autoload :Base,  File.join(SYNCER_PATH, 'rsync', 'base')
      autoload :Local, File.join(SYNCER_PATH, 'rsync', 'local')
      autoload :Push,  File.join(SYNCER_PATH, 'rsync', 'push')
      autoload :Pull,  File.join(SYNCER_PATH, 'rsync', 'pull')
    end
  end

  ##
  # Autoload Backup database files
  module Database
    autoload :Base,       File.join(DATABASE_PATH, 'base')
    autoload :MySQL,      File.join(DATABASE_PATH, 'mysql')
    autoload :PostgreSQL, File.join(DATABASE_PATH, 'postgresql')
    autoload :MongoDB,    File.join(DATABASE_PATH, 'mongodb')
    autoload :Redis,      File.join(DATABASE_PATH, 'redis')
    autoload :Riak,       File.join(DATABASE_PATH, 'riak')
  end

  ##
  # Autoload compressor files
  module Compressor
    autoload :Base,   File.join(COMPRESSOR_PATH, 'base')
    autoload :Gzip,   File.join(COMPRESSOR_PATH, 'gzip')
    autoload :Bzip2,  File.join(COMPRESSOR_PATH, 'bzip2')
    autoload :Custom, File.join(COMPRESSOR_PATH, 'custom')
    autoload :Pbzip2, File.join(COMPRESSOR_PATH, 'pbzip2')
    autoload :Lzma,   File.join(COMPRESSOR_PATH, 'lzma')
  end

  ##
  # Autoload encryptor files
  module Encryptor
    autoload :Base,    File.join(ENCRYPTOR_PATH, 'base')
    autoload :OpenSSL, File.join(ENCRYPTOR_PATH, 'open_ssl')
    autoload :GPG,     File.join(ENCRYPTOR_PATH, 'gpg')
  end

  ##
  # Autoload notification files
  module Notifier
    autoload :Base,      File.join(NOTIFIER_PATH, 'base')
    autoload :Binder,    File.join(NOTIFIER_PATH, 'binder')
    autoload :Mail,      File.join(NOTIFIER_PATH, 'mail')
    autoload :Twitter,   File.join(NOTIFIER_PATH, 'twitter')
    autoload :Campfire,  File.join(NOTIFIER_PATH, 'campfire')
    autoload :Prowl,     File.join(NOTIFIER_PATH, 'prowl')
    autoload :Hipchat,   File.join(NOTIFIER_PATH, 'hipchat')
    autoload :Pushover,  File.join(NOTIFIER_PATH, 'pushover')
  end

  ##
  # Require Backup base files
  %w{
    archive
    binder
    cleaner
    config
    configuration
    dependency
    errors
    logger
    model
    package
    packager
    pipeline
    splitter
    template
    version
  }.each {|lib| require File.join(LIBRARY_PATH, lib) }

end
