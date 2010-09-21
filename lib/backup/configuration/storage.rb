module Backup
  module Configuration
    class Storage
      extend Backup::Configuration::Attributes
      generate_attributes %w(ip user password path access_key_id secret_access_key host use_ssl bucket username api_key container)
    end
  end
end
