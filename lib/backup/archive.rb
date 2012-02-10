# encoding: utf-8

module Backup
  class Archive
    include Backup::CLI::Helpers

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
    # String of additional arguments for the `tar` command
    attr_accessor :tar_args

    ##
    # Takes the name of the archive and the configuration block
    def initialize(model, name, &block)
      @model    = model
      @name     = name.to_s
      @paths    = Array.new
      @excludes = Array.new
      @tar_args = ''

      instance_eval(&block) if block_given?
    end

    ##
    # Adds new paths to the @paths instance variable array
    def add(path)
      path = File.expand_path(path)
      if File.exist?(path)
        @paths << path
      else
        Logger.warn Errors::Archive::NotFoundError.new(<<-EOS)
          The following path was not found:
          #{ path }
          This path will be omitted from the '#{ name }' Archive.
        EOS
      end
    end

    ##
    # Adds new paths to the @excludes instance variable array
    def exclude(path)
      @excludes << File.expand_path(path)
    end

    ##
    # Adds the given String of +options+ to the `tar` command.
    # e.g. '-h --xattrs'
    def tar_options(options)
      @tar_args = options
    end

    ##
    # Archives all the provided paths in to a single .tar file
    # and places that .tar file in the folder which later will be packaged
    # If the model is configured with a Compressor, the tar command output
    # will be piped through the Compressor command and the file extension
    # will be adjusted to indicate the type of compression used.
    def perform!
      Logger.message "#{ self.class } started packaging and archiving:\n" +
          paths.map {|path| "  #{path}" }.join("\n")

      archive_path = File.join(Config.tmp_path, @model.trigger, 'archives')
      FileUtils.mkdir_p(archive_path)

      archive_ext = 'tar'
      archive_cmd = "#{ utility(:tar) } #{ tar_args } -cf - " +
          "#{ paths_to_exclude } #{ paths_to_package }"

      if @model.compressor
        @model.compressor.compress_with do |command, ext|
          archive_cmd << " | #{command}"
          archive_ext << ext
        end
      end

      archive_cmd << " > '#{ File.join(archive_path, "#{name}.#{archive_ext}") }'"

      run(archive_cmd)
    end

    private

    ##
    # Returns a "tar-ready" string of all the specified paths combined
    def paths_to_package
      paths.map {|path| "'#{path}'" }.join(' ')
    end

    ##
    # Returns a "tar-ready" string of all the specified excludes combined
    def paths_to_exclude
      if excludes.any?
        excludes.map {|path| "--exclude='#{path}'" }.join(' ')
      end
    end

  end
end
