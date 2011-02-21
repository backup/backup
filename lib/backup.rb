# encoding: utf-8

require 'fileutils'
require 'yaml'

##
# Backup's directory path constants
LIBRARY_PATH       = File.join(File.dirname(__FILE__), 'backup')
CONFIGURATION_PATH = File.join(LIBRARY_PATH, 'configuration')
STORAGE_PATH       = File.join(LIBRARY_PATH, 'storage')
DATABASE_PATH      = File.join(LIBRARY_PATH, 'database')
COMPRESSOR_PATH    = File.join(LIBRARY_PATH, 'compressor')
TMP_PATH           = File.join(ENV['HOME'], 'tmp', 'backup')

##
# Backup Ruby Gem
module Backup

  ##
  # Autoload Backup base files
  autoload :Model,   File.join(LIBRARY_PATH, 'model')
  autoload :Archive, File.join(LIBRARY_PATH, 'archive')
  autoload :CLI,     File.join(LIBRARY_PATH, 'cli')
  autoload :Finder,  File.join(LIBRARY_PATH, 'finder')
  autoload :Version, File.join(LIBRARY_PATH, 'version')

  ##
  # Autoload Backup configuration files
  module Configuration
    autoload :Base, File.join(CONFIGURATION_PATH, 'base')
    autoload :S3,   File.join(CONFIGURATION_PATH, 's3')
    autoload :Mail, File.join(CONFIGURATION_PATH, 'mail')
  end

  ##
  # Autoload Backup storage files
  module Storage
    autoload :Base, File.join(STORAGE_PATH, 'base')
    autoload :S3,   File.join(STORAGE_PATH, 's3')
  end

  ##
  # Autoload Backup database files
  module Database
    autoload :MySQL, File.join(DATABASE_PATH, 'mysql')
  end

  ##
  # Autoload compressor files
  module Compressor
    autoload :Gzip, File.join(COMPRESSOR_PATH, 'gzip')
  end

end
