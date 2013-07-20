# encoding: utf-8

module Backup

  # Provides cascading errors with formatted messages.
  # See the specs for details.
  module NestedExceptions

    def self.included(klass)
      klass.extend Module.new {
        def wrap(wrapped_exception, msg = nil)
          new(msg, wrapped_exception)
        end
      }
    end

    def initialize(obj = nil, wrapped_exception = nil)
      @wrapped_exception = wrapped_exception
      msg = (obj.respond_to?(:to_str) ? obj.to_str : obj.to_s).
            gsub(/^ */, '  ').strip
      msg = clean_name(self.class.name) + (msg.empty? ? '' : ": #{ msg }")

      if wrapped_exception
        msg << "\n--- Wrapped Exception ---\n"
        class_name = clean_name(wrapped_exception.class.name)
        msg << class_name + ': ' unless
            wrapped_exception.message.start_with? class_name
        msg << wrapped_exception.message
      end

      super(msg)
      set_backtrace(wrapped_exception.backtrace) if wrapped_exception
    end

    def exception(obj = nil)
      return self if obj.nil? || equal?(obj)

      ex = self.class.new(obj, @wrapped_exception)
      ex.set_backtrace(backtrace) unless ex.backtrace
      ex
    end

    private

    def clean_name(name)
      name.sub(/^Backup::/, '')
    end

  end

  class Error < StandardError
    include NestedExceptions
  end

  class FatalError < Exception
    include NestedExceptions
  end
end
