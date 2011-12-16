# encoding: utf-8

require 'erb'

module Backup
  class Template

    # Holds a binding object. Nil if not provided.
    attr_accessor :binding

    ##
    # Creates a new instance of the Backup::Template class
    # and optionally takes an argument that can be either a binding object, a Hash or nil
    def initialize(object = nil)
      if object.is_a?(Binding)
        @binding = object
      elsif object.is_a?(Hash)
        @binding = Backup::Binder.new(object).get_binding
      else
        @binding = nil
      end
    end

    ##
    # Renders the provided file (in the context of the binding if any) to the console
    def render(file)
      puts result(file)
    end

    ##
    # Returns a String object containing the contents of the file (in the context of the binding if any)
    def result(file)
      ERB.new(file_contents(file), nil, '<>').result(binding)
    end

  private

    ##
    # Reads and returns the contents of the provided file path,
    # relative from the Backup::TEMPLATE_PATH
    def file_contents(file)
      File.read(File.join(Backup::TEMPLATE_PATH, file))
    end

  end
end
