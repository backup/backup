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
          msg = "#{ self }##{ name } has been deprecated as of " +
              "backup v.#{ deprecation[:version] }"
          msg << "\n#{ deprecation[:message] }" if deprecation[:message]
          Logger.warn Backup::Errors::ConfigurationError.new <<-EOS
            [DEPRECATION WARNING]
            #{ msg }
          EOS
        end

        protected

        ##
        # Method to deprecate an attribute.
        #
        # :version
        #   Must be set to the backup version which will first
        #   introduce the deprecation.
        #
        # :action
        #   If set, this Proc will be called with a reference to the
        #   class instance and the value set on the deprecated accessor.
        #   e.g. deprecation[:action].call(klass, value)
        #   This should perform whatever action is neccessary, such as
        #   transferring the value to a new accessor.
        #
        # :message
        #   If set, this will be appended to #log_deprecation_warning
        #
        # Note that this replaces the `attr_accessor` method, or other
        # method previously used to set the accessor being deprecated.
        # #method_missing will handle any calls to `name=`.
        #
        def attr_deprecate(name, args = {})
          deprecations[name] = {
            :version => nil,
            :message => nil,
            :action => nil
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

      ##
      # Check missing methods for deprecated attribute accessors.
      #
      # If a value is set on an accessor that has been deprecated
      # using #attr_deprecate, a warning will be issued and any
      # :action (Proc) specified will be called with a reference to
      # the class instance and the value set on the deprecated accessor.
      # See #attr_deprecate and #log_deprecation_warning
      #
      # Note that OpenStruct (used for setting defaults) does not allow
      # multiple arguments when assigning values for members.
      # So, we won't allow it here either, even though an attr_accessor
      # will accept and convert them into an Array. Therefore, setting
      # an option value using multiple values, whether as a default or
      # directly on the class' accessor, should not be supported.
      # i.e. if an option will accept being set as an Array, then it
      # should be explicitly set as such. e.g. option = [val1, val2]
      #
      def method_missing(name, *args)
        deprecation = nil
        if method = name.to_s.chomp!('=')
          if (len = args.count) != 1
            raise ArgumentError,
              "wrong number of arguments (#{ len } for 1)", caller(1)
          end
          deprecation = self.class.deprecations[method.to_sym]
        end

        if deprecation
          self.class.log_deprecation_warning(method, deprecation)
          deprecation[:action].call(self, args[0]) if deprecation[:action]
        else
          super
        end
      end

    end
  end
end
