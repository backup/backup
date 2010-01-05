module Backup
  module Configuration
    class Storage
      extend Backup::Configuration::Attributes
      generate_attributes %w(ip user password path access_key_id secret_access_key use_ssl bucket)
    end
  end
end
