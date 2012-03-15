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

        def deprecations
          @deprecations ||= {}
        end

        def log_deprecation_warning(name, deprecation)
          msg = "#{ self }.#{ name } has been deprecated as of " +
              "backup v.#{ deprecation[:version] }"
          if replacement = deprecation[:replacement]
            msg << "\nThis setting has been replaced with:\n" +
                "#{ self }.#{ replacement }"
          end
          Logger.warn Backup::Errors::ConfigurationError.new <<-EOS
            [DEPRECATION WARNING]
            #{ msg }
          EOS
        end

        protected

        def attr_deprecate(name, args = {})
          deprecations[name] = {
            :version => nil,
            :replacement => nil
          }.merge(args)
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

      def method_missing(name, *args)
        deprecation = nil
        if method = name.to_s.chomp!('=')
          deprecation = self.class.deprecations[method.to_sym]
        end

        if deprecation
          self.class.log_deprecation_warning(method, deprecation)
          replacement = deprecation[:replacement]
          send(:"#{ replacement }=", *args) if replacement
        else
          super
        end
      end

    end
  end
end
