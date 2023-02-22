require "erb"

module Backup
  class Template
    # Holds a binding object. Nil if not provided.
    attr_accessor :binding

    ##
    # Creates a new instance of the Backup::Template class
    # and optionally takes an argument that can be either a binding object, a Hash or nil
    def initialize(object = nil)
      @binding =
        if object.is_a?(Binding)
          object
        elsif object.is_a?(Hash)
          Backup::Binder.new(object).get_binding
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
      if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.0.0")
        ERB.new(file_contents(file), trim_mode: "<>")
      else
        ERB.new(file_contents(file), nil, "<>")
      end.result(binding)
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
