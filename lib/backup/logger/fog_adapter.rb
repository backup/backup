# encoding: utf-8

# require only the logger
require 'formatador'
require 'fog/core/logger'

module Backup
  class Logger
    module FogAdapter
      class << self

        # Logged as :info so these won't generate warnings.
        # This is mostly to keep STDOUT clean and to provide
        # supplemental messages for our own warnings.
        # These will generally occur during retry attempts.
        def write(message)
          Logger.info message.split("\n").
              map {|line| "[fog] #{ line }" }.join("\n")
        end

        def tty?
          false
        end

      end
    end
  end
end

Fog::Logger[:warning] = Backup::Logger::FogAdapter
