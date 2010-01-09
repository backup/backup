module Backup
  module Configuration
    class SMTP
      extend Backup::Configuration::Attributes
      generate_attributes %w(host port username password authentication domain tls)
    end
  end
end
