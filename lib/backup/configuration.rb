# encoding: utf-8

require 'backup/configuration/helpers'
require 'backup/configuration/store'

# Temporary measure for deprecating the use of Configuration
# namespaced classes for setting pre-configured defaults.
module Backup
  module Configuration
    extend self

    ##
    # Pass calls on to the proper class and log a warning
    def defaults(&block)
      klass = eval(self.to_s.sub('Configuration::', ''))
      Logger.warn Errors::ConfigurationError.new <<-EOS
        [DEPRECATION WARNING]
        #{ self }.defaults is being deprecated.
        To set pre-configured defaults for #{ klass }, use:
        #{ klass }.defaults
      EOS
      klass.defaults(&block)
    end

    def clear_defaults!
      klass = eval(self.to_s.sub('Configuration::', ''))
      klass.clear_defaults!
    end

    private

    def const_missing(const)
      mod = Module.new do
        extend Configuration
        class << self
          undef_method :name
        end
      end
      const_set(const, mod)
    end

    def method_missing(name, *args)
      if !name.to_s.end_with?('=') && args.count == 0
        defaults.send(name)
      else
        super(name, *args)
      end
    end

  end
end
