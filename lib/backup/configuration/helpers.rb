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

        ##
        # Method to deprecate an attribute.
        #
        # :version should be set to the backup version which will first
        #   introduce the deprecation.
        # :replacement may be set to another attr_accessor name to set
        #   the value for instead of the deprecated accessor
        # :value may be used to specify the value set on :replacement.
        #   If :value is nil, the value set on the deprecated accessor
        #   will be used to set the value for the :replacement.
        #   If :value is a lambda, it will be passed the value the user
        #   set on the deprecated accessor, and should return the value
        #   to be set on the :replacement.
        #   Therefore, to cause the replacement accessor not to be set,
        #   use the lambda form to return nil. This is only way to specify
        #   a :replacement without transferring a value.
        #   e.g. :replacement => :new_attr, :value => Proc.new {}
        def attr_deprecate(name, args = {})
          deprecations[name] = {
            :version => nil,
            :replacement => nil,
            :value => nil
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
      # Check missing methods for deprecations
      #
      # Note that OpenStruct (used for setting defaults) does not allow
      # multiple arguments when assigning values for members.
      # So, we won't allow it here either, even though an attr_accessor
      # will accept and convert them into an Array. Therefore, setting
      # an option value using multiple values, whether as a default or
      # directly on the class' accessor, should not be supported.
      # i.e. if an option will accept being set as an Array, then it
      # should be explicitly set as such. e.g. option = [val1, val2]
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
          if replacement = deprecation[:replacement]
            value =
              case deprecation[:value]
              when nil
                args[0]
              when Proc
                deprecation[:value].call(args[0])
              else
                deprecation[:value]
              end
            unless value.nil?
              Logger.warn(
                "#{ self.class }.#{ replacement } is being set to '#{ value }'"
              )
              send(:"#{ replacement }=", value)
            end
          end
        else
          super
        end
      end

    end
  end
end
