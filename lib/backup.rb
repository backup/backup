# encoding: utf-8

##
# Backup's directory path constants
LIBRARY_PATH       = File.join(File.dirname(__FILE__), 'backup')
CONFIGURATION_PATH = File.join(LIBRARY_PATH, 'configuration')
STORAGE_PATH       = File.join(LIBRARY_PATH, 'storage')

##
# Backup Ruby Gem
module Backup

  ##
  # Autoload Backup base files
  autoload :Model,   File.join(LIBRARY_PATH, 'model')
  autoload :Version, File.join(LIBRARY_PATH, 'version')

  ##
  # Autoload Backup configuration files
  module Configuration
    autoload :S3, File.join(CONFIGURATION_PATH, 's3')
    autoload :Mail, File.join(CONFIGURATION_PATH, 'mail')
  end

  ##
  # Autoload Backup storage files
  module Storage
    autoload :S3, File.join(STORAGE_PATH, 's3')
  end

end
