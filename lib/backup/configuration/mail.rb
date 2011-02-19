# encoding: utf-8

module Backup
  module Configuration
    class Mail
      class << self
        attr_accessor :from, :to, :address, :port, :domain, :user_name, :password,
                      :authentication, :enable_starttls_auto
      end

      ##
      # Sets the default Mail configuration to make
      # larger configuration sets less verbose
      #
      # By setting the configurations here, they will become the default
      # througout the backup process. These defaults can be (individually)
      # overwritten by the Backup::Model
      def self.defaults
        yield self
      end
    end
  end
end
