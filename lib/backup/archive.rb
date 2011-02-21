# encoding: utf-8

module Backup
  class Archive
    include Backup::CLI

    ##
    # Stores the name of the archive
    attr_accessor :name

    ##
    # Stores an array of different paths/files to store
    attr_accessor :paths

    ##
    # Stores the path to the archive directory
    attr_accessor :archive_path

    ##
    # Takes the name of the archive and the configuration block
    def initialize(name, &block)
      @name         = name.to_sym
      @paths        = Array.new
      @archive_path = File.join(TMP_PATH, TRIGGER, 'archive')

      instance_eval(&block)
    end

    ##
    # Adds new paths to the @paths instance variable array
    def add(path)
      @paths << path
    end

    ##
    # Archives all the provided paths in to a single .tar file
    # and places that .tar file in the folder which later will be packaged
    def perform!
      mkdir(archive_path)
      run("#{ utility(:tar) } -c #{ paths_to_package } &> /dev/null > '#{ File.join(archive_path, "#{name}.tar") }'")
    end

  private

    ##
    # Returns a "tar-ready" string of all the specified paths combined
    def paths_to_package
      paths.map do |path|
        "'#{path}'"
      end.join("\s")
    end
  end
end
