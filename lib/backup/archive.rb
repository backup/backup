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
    # Stores an array of different paths/files to exclude
    attr_accessor :excludes

    ##
    # Stores the path to the archive directory
    attr_accessor :archive_path

    ##
    # Takes the name of the archive and the configuration block
    def initialize(name, &block)
      @name         = name.to_sym
      @paths        = Array.new
      @excludes     = Array.new
      @archive_path = File.join(TMP_PATH, TRIGGER, 'archive')

      instance_eval(&block)
    end

    ##
    # Adds new paths to the @paths instance variable array
    def add(path)
      @paths << path
    end

    ##
    # Adds new paths to the @excludes instance variable array
    def exclude(path)
      @excludes << path
    end

    ##
    # Archives all the provided paths in to a single .tar file
    # and places that .tar file in the folder which later will be packaged
    def perform!
      mkdir(archive_path)
      Logger.message("#{ self.class } started packaging and archiving #{ paths.map { |path| "\"#{path}\""}.join(", ") }.")
      run("#{ utility(:tar) } -c -f #{ File.join(archive_path, "#{name}.tar") } #{ paths_to_exclude } #{ paths_to_package } 2> /dev/null")
    end

  private

    ##
    # Returns a "tar-ready" string of all the specified paths combined
    def paths_to_package
      paths.map do |path|
        "'#{path}'"
      end.join("\s")
    end

    ##
    # Returns a "tar-ready" string of all the specified excludes combined
    def paths_to_exclude
      if excludes.any?
        "--exclude={" + excludes.map{ |e| "'#{e}'" }.join(",") + "}"
      end
    end
  end
end
