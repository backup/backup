# encoding: utf-8

module Backup
  module Configuration
    class Base

      ##
      # Clears all the defaults that may have been set by the user
      def self.clear_defaults!
        methods.each do |method|
          method = method.to_s
          if method =~ /^\w(\w|\d)+\=$/ and method != 'taguri='
            self.send(method, nil)
          end
        end
      end

    end
  end
end
