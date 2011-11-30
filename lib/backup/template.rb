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
    # Renders the given file in the context of the provided binding (if any)
    # and directly outputs the data to the console. The file path is relative from the
    # root of the templates directory (Backup::TEMPLATE_PATH).
    # The erb extension should be omitted from the file argument.
    def render(file)
      puts ERB.new(file_contents(file)).result(binding)
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
