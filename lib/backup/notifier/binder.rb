# encoding: utf-8

module Backup
  module Notifier
    class Binder

      ##
      # Shortcut to create a new instance of a binder, setting
      # the instance variables using a Hash of key/values and getting
      # the instance's binding. This returns the binding of the new Binder instance
      def self.bind(key_and_values = {})
        Binder.new(key_and_values).get_binding
      end

      ##
      # Creates a new Backup::Notifier::Binder instance. Loops through the provided
      # Hash to set instance variables
      def initialize(key_and_values)
        key_and_values.each do |key, value|
          instance_variable_set("@#{key}", value)
        end
      end

      ##
      # Returns the binding (needs a wrapper method because #binding is a private method)
      def get_binding
        binding
      end

    end
  end
end
