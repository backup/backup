# encoding: utf-8
require 'backup/config/dsl'
require 'backup/config/helpers'

module Backup
  module Config
    class Error < Backup::Error; end

    DEFAULTS = {
      :config_file  => 'config.rb',
      :data_path    => '.data',
      :tmp_path     => '.tmp'
    }

    class << self
      include Utilities::Helpers

      attr_reader :user, :root_path, :config_file, :data_path, :tmp_path

      # Loads the user's +config.rb+ and all model files.
      def load(options = {})
        update(options)  # from the command line

        unless File.exist?(config_file)
          raise Error, "Could not find configuration file: '#{config_file}'."
        end

        config = File.read(config_file)
        version = Backup::VERSION.split('.').first
        unless config =~ /^# Backup v#{ version }\.x Configuration$/
          raise Error, <<-EOS
            Invalid Configuration File
            The configuration file at '#{ config_file }'
            does not appear to be a Backup v#{ version }.x configuration file.
            If you have upgraded to v#{ version }.x from a previous version,
            you need to upgrade your configuration file.
            Please see the instructions for upgrading in the Backup documentation.
          EOS
        end

        dsl = DSL.new
        dsl.instance_eval(config, config_file)

        update(dsl._config_options)  # from config.rb
        update(options)              # command line takes precedence

        Dir[File.join(File.dirname(config_file), 'models', '*.rb')].each do |model|
          dsl.instance_eval(File.read(model), model)
        end
      end

      def hostname
        @hostname ||= run(utility(:hostname))
      end

      private

      # If :root_path is set in the options, all paths will be updated.
      # Otherwise, only the paths given will be updated.
      def update(options = {})
        root_path = options[:root_path].to_s.strip
        new_root = root_path.empty? ? false : set_root_path(root_path)

        DEFAULTS.each do |name, ending|
          set_path_variable(name, options[name], ending, new_root)
        end
      end

      # Sets the @root_path to the given +path+ and returns it.
      # Raises an error if the given +path+ does not exist.
      def set_root_path(path)
        # allows #reset! to set the default @root_path,
        # then use #update to set all other paths,
        # without requiring that @root_path exist.
        return @root_path if path == @root_path

        path = File.expand_path(path)
        unless File.directory?(path)
          raise Error, <<-EOS
            Root Path Not Found
            When specifying a --root-path, the path must exist.
            Path was: #{ path }
          EOS
        end
        @root_path = path
      end

      def set_path_variable(name, path, ending, root_path)
        # strip any trailing '/' in case the user supplied this as part of
        # an absolute path, so we can match it against File.expand_path()
        path = path.to_s.sub(/\/\s*$/, '').lstrip
        new_path = false
        # If no path is given, the variable will not be set/updated
        # unless a root_path was given. In which case the value will
        # be updated with our default ending.
        if path.empty?
          new_path = File.join(root_path, ending) if root_path
        else
          # When a path is given, the variable will be set/updated.
          # If the path is relative, it will be joined with root_path (if given),
          # or expanded relative to PWD.
          new_path = File.expand_path(path)
          unless path == new_path
            new_path = File.join(root_path, path) if root_path
          end
        end
        instance_variable_set(:"@#{name}", new_path) if new_path
      end

      def reset!
        @user      = ENV['USER'] || Etc.getpwuid.name
        @root_path = File.join(File.expand_path(ENV['HOME'] || ''), 'Backup')
        update(:root_path => @root_path)
      end
    end

    reset!  # set defaults on load
  end
end
