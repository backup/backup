# encoding: utf-8

##
# Backup's directory path constants
LIBRARY_PATH       = File.join(File.dirname(__FILE__), 'backup')
CONFIGURATION_PATH = File.join(LIBRARY_PATH, 'configuration')

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
  end

end
