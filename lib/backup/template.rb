# encoding: utf-8

require 'erb'

module Backup
  class Template

    # Holds a binding object. Nil if not provided.
    attr_accessor :binding

    ##
    # Creates a new instance of the Backup::Template class
    # and optionally takes a binding object to render templates in the context of another object
    def initialize(binding = nil)
      @binding = binding
    end

    ##
    # Renders the provided file (in the context of the binding if any) to the console
    def render(file)
      puts result(file)
    end

    ##
    # Returns a String object containing the contents of the file (in the context of the binding if any)
    def result(file)
      ERB.new(file_contents(file)).result(binding)
    end

  private

    ##
    # Reads and returns the contents of the provided file path,
    # relative from the Backup::TEMPLATE_PATH
    def file_contents(file)
      File.read(File.join(Backup::TEMPLATE_PATH, "#{ file }.erb"))
    end

  end
end
