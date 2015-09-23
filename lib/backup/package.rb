# encoding: utf-8

module Backup
  class Package

    ##
    # The time when the backup initiated (in format: 2011.02.20.03.29.59)
    attr_accessor :time

    ##
    # The trigger which initiated the backup process
    attr_reader :trigger

    ##
    # Extension for the final archive file(s)
    attr_accessor :extension

    ##
    # Set by the Splitter if the final archive was "chunked"
    attr_accessor :chunk_suffixes

    ##
    # If true, the Cycler will not attempt to remove the package when Cycling.
    attr_accessor :no_cycle

    ##
    # The version of Backup used to create the package
    attr_reader :version

    def initialize(model)
      @trigger = model.trigger
      @extension = 'tar'
      @chunk_suffixes = Array.new
      @no_cycle = false
      @version = VERSION
    end

    def filenames
      if chunk_suffixes.empty?
        [basename]
      else
        chunk_suffixes.map {|suffix| "#{ basename }-#{ suffix }" }
      end
    end

    def basename
      "#{ trigger }.#{ extension }"
    end

    def time_as_object
      Time.strptime(time, '%Y.%m.%d.%H.%M.%S')
    end

  end
end
