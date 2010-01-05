module Backup
  module Configuration
    class AdapterOptions
      extend Backup::Configuration::Attributes
      generate_attributes %w(host port socket)
    end
  end
end
