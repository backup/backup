# encoding: utf-8

module Backup
  module Configuration
    module Helpers

      ##
      # Finds all the object's getter methods and checks the global
      # configuration for these methods, if they respond then they will
      # assign the object's attribute(s) to that particular global configuration's attribute
      def load_defaults!
        c             = self.class.name.split('::')
        configuration = Backup::Configuration.const_get(c[1]).const_get(c[2])

        getter_methods.each do |attribute|
          if configuration.respond_to?(attribute)
            self.send("#{attribute}=", configuration.send(attribute))
          end
        end
      end

      ##
      # Clears all the defaults that may have been set by the user
      def clear_defaults!
        setter_methods.each do |method|
          self.send(method, nil)
        end
      end

      ##
      # Returns an array of the setter methods (as String)
      def setter_methods
        methods.map do |method|
          method = method.to_s
          method if method =~ /^\w(\w|\d|\_)+\=$/ and method != 'taguri='
        end.compact
      end

      ##
      # Returns an array of getter methods (as Array)
      def getter_methods
        methods.map do |method|
          method = method.to_s
          if method =~ /^\w(\w|\d|\_)+\=$/ and method != 'taguri='
            method.sub('=','')
          end
        end.compact
      end

    end
  end
end
