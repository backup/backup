# encoding: utf-8

%w[helpers store].each do |file|
  require File.expand_path("../configuration/#{file}", __FILE__)
end

# Temporary measure for deprecating the use of Configuration
# namespaced classes for setting pre-configured defaults.
module Backup
  module Configuration
    extend self

    ##
    # Pass calls on to the proper class and log a warning
    def defaults(&block)
      klass = eval(self.to_s.sub('Configuration::', ''))
      Logger.warn Error.new(<<-EOS)
        [DEPRECATION WARNING]
        #{ self }.defaults is being deprecated.
        To set pre-configured defaults for #{ klass }, use:
        #{ klass }.defaults
      EOS
      klass.defaults(&block)
    end

    private

    def const_missing(const)
      const_set(const, Module.new { extend Configuration })
    end

  end
end
