# encoding: utf-8

module Backup
  module Configuration
    module Helpers

      def self.included(klass)
        klass.extend ClassMethods
      end

      module ClassMethods

        ##
        # Returns or yields the Configuration::Store
        # for storing pre-configured defaults for the class.
        def defaults
          @configuration ||= Configuration::Store.new

          if block_given?
            yield @configuration
          else
            @configuration
          end
        end

        ##
        # Used only within the specs
        def clear_defaults!
          defaults.reset!
        end

      end # ClassMethods

      private

      ##
      # Sets any pre-configured default values.
      # If a default value was set for an invalid accessor,
      # this will raise a NameError.
      def load_defaults!
        configuration = self.class.defaults
        configuration._attributes.each do |name|
          send(:"#{ name }=", configuration.send(name))
        end
      end

    end
  end
end
