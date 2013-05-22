# encoding: utf-8

module Backup
  ##
  # - automatically defines module namespaces referenced under Backup::Errors
  # - any constant name referenced that ends with 'Error' will be created
  #   as a subclass of Backup::Errors::Error
  # - any constant name referenced that ends with 'FatalError' will be created
  #   as a subclass of Backup::Errors::FatalError
  #
  # e.g.
  #   err = Backup::Errors::Foo::Bar::FooError.new('error message')
  #   err.message => "Foo::Bar::FooError: error message"
  #
  #   err = Backup::Errors::Foo::Bar::FooFatalError.new('error message')
  #   err.message => "Foo::Bar::FooFatalError: error message"
  #
  module ErrorsHelper
    def const_missing(const)
      if const.to_s.end_with?('FatalError')
        module_eval("class #{const} < Backup::Errors::FatalError; end")
      elsif const.to_s.end_with?('Error')
        module_eval("class #{const} < Backup::Errors::Error; end")
      else
        module_eval("module #{const}; extend Backup::ErrorsHelper; end")
      end
      const_get(const)
    end
  end

  module Errors
    extend ErrorsHelper

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
        name.sub(/^Backup::Errors::/, '')
      end

    end

    class Error < StandardError
      include NestedExceptions
    end

    class FatalError < Exception
      include NestedExceptions
    end

  end
end
