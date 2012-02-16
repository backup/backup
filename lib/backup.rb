# encoding: utf-8

# Load Ruby Core Libraries
require 'rubygems'
require 'fileutils'
require 'tempfile'
require 'yaml'
require 'etc'

# Attempt load to POpen4 and Thor Libraries
begin
  gem 'POpen4', '~> 0.1.4'
  gem 'thor',   '~> 0.14.6'
  require 'popen4'
  require 'thor'
rescue LoadError
  puts "\nBackup requires Thor to load the CLI Utility (Command Line Interface Utility) and POpen4 to determine the status of the unix processes."
  puts "Please install both the Thor and POpen4 libraries first:\n\ngem install thor -v '~> 0.14.6'\ngem install POpen4 -v '~> 0.1.4'"
  exit 1
end

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
  CONFIGURATION_PATH = File.join(LIBRARY_PATH, 'configuration')
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
    autoload :Base,       File.join(SYNCER_PATH, 'base')
    autoload :Cloud,      File.join(SYNCER_PATH, 'cloud')
    autoload :CloudFiles, File.join(SYNCER_PATH, 'cloud_files')
    autoload :S3,         File.join(SYNCER_PATH, 's3')
    module RSync
      autoload :Base,  File.join(SYNCER_PATH, 'rsync', 'base')
      autoload :Local, File.join(SYNCER_PATH, 'rsync', 'local')
      autoload :Push,  File.join(SYNCER_PATH, 'rsync', 'push')
      autoload :Pull,  File.join(SYNCER_PATH, 'rsync', 'pull')
    end
    module SCM
      autoload :Base, File.join(SYNCER_PATH, 'scm', 'base')
      autoload :Git,  File.join(SYNCER_PATH, 'scm', 'git')
      autoload :SVN,  File.join(SYNCER_PATH, 'scm', 'svn')
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
    autoload :Presently, File.join(NOTIFIER_PATH, 'presently')
    autoload :Prowl,     File.join(NOTIFIER_PATH, 'prowl')
    autoload :Hipchat,   File.join(NOTIFIER_PATH, 'hipchat')
  end

  ##
  # Autoload Backup configuration files
  module Configuration
    autoload :Base,     File.join(CONFIGURATION_PATH, 'base')
    autoload :Helpers,  File.join(CONFIGURATION_PATH, 'helpers')

    module Notifier
      autoload :Base,      File.join(CONFIGURATION_PATH, 'notifier', 'base')
      autoload :Mail,      File.join(CONFIGURATION_PATH, 'notifier', 'mail')
      autoload :Twitter,   File.join(CONFIGURATION_PATH, 'notifier', 'twitter')
      autoload :Campfire,  File.join(CONFIGURATION_PATH, 'notifier', 'campfire')
      autoload :Presently, File.join(CONFIGURATION_PATH, 'notifier', 'presently')
      autoload :Prowl,     File.join(CONFIGURATION_PATH, 'notifier', 'prowl')
      autoload :Hipchat,   File.join(CONFIGURATION_PATH, 'notifier', 'hipchat')
    end

    module Encryptor
      autoload :Base,    File.join(CONFIGURATION_PATH, 'encryptor', 'base')
      autoload :OpenSSL, File.join(CONFIGURATION_PATH, 'encryptor', 'open_ssl')
      autoload :GPG,     File.join(CONFIGURATION_PATH, 'encryptor', 'gpg')
    end

    module Compressor
      autoload :Base,   File.join(CONFIGURATION_PATH, 'compressor', 'base')
      autoload :Gzip,   File.join(CONFIGURATION_PATH, 'compressor', 'gzip')
      autoload :Bzip2,  File.join(CONFIGURATION_PATH, 'compressor', 'bzip2')
      autoload :Pbzip2, File.join(CONFIGURATION_PATH, 'compressor', 'pbzip2')
      autoload :Lzma,   File.join(CONFIGURATION_PATH, 'compressor', 'lzma')
    end

    module Storage
      autoload :Base,       File.join(CONFIGURATION_PATH, 'storage', 'base')
      autoload :S3,         File.join(CONFIGURATION_PATH, 'storage', 's3')
      autoload :CloudFiles, File.join(CONFIGURATION_PATH, 'storage', 'cloudfiles')
      autoload :Ninefold,   File.join(CONFIGURATION_PATH, 'storage', 'ninefold')
      autoload :Dropbox,    File.join(CONFIGURATION_PATH, 'storage', 'dropbox')
      autoload :FTP,        File.join(CONFIGURATION_PATH, 'storage', 'ftp')
      autoload :SFTP,       File.join(CONFIGURATION_PATH, 'storage', 'sftp')
      autoload :SCP,        File.join(CONFIGURATION_PATH, 'storage', 'scp')
      autoload :RSync,      File.join(CONFIGURATION_PATH, 'storage', 'rsync')
      autoload :Local,      File.join(CONFIGURATION_PATH, 'storage', 'local')
    end

    module Syncer
      autoload :Base,       File.join(CONFIGURATION_PATH, 'syncer', 'base')
      autoload :Cloud,      File.join(CONFIGURATION_PATH, 'syncer', 'cloud')
      autoload :CloudFiles, File.join(CONFIGURATION_PATH, 'syncer', 'cloud_files')
      autoload :S3,         File.join(CONFIGURATION_PATH, 'syncer', 's3')
      module SCM
        autoload :Base,     File.join(CONFIGURATION_PATH, 'syncer', 'scm', 'base')
        autoload :Git,      File.join(CONFIGURATION_PATH, 'syncer', 'scm', 'git')
        autoload :SVN,      File.join(CONFIGURATION_PATH, 'syncer', 'scm', 'svn')
      end
      module RSync
        autoload :Base,     File.join(CONFIGURATION_PATH, 'syncer', 'rsync', 'base')
        autoload :Local,    File.join(CONFIGURATION_PATH, 'syncer', 'rsync', 'local')
        autoload :Push,     File.join(CONFIGURATION_PATH, 'syncer', 'rsync', 'push')
        autoload :Pull,     File.join(CONFIGURATION_PATH, 'syncer', 'rsync', 'pull')
      end
    end

    module Database
      autoload :Base,       File.join(CONFIGURATION_PATH, 'database', 'base')
      autoload :MySQL,      File.join(CONFIGURATION_PATH, 'database', 'mysql')
      autoload :PostgreSQL, File.join(CONFIGURATION_PATH, 'database', 'postgresql')
      autoload :MongoDB,    File.join(CONFIGURATION_PATH, 'database', 'mongodb')
      autoload :Redis,      File.join(CONFIGURATION_PATH, 'database', 'redis')
      autoload :Riak,       File.join(CONFIGURATION_PATH, 'database', 'riak')
    end
  end

  ##
  # Require Backup base files
  %w{
    model
    archive
    packager
    package
    cleaner
    splitter
    config
    binder
    template
    dependency
    logger
    version
    errors
  }.each {|lib| require File.join(LIBRARY_PATH, lib) }

end
