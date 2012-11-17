# encoding: utf-8

module Backup
  module Config
    DEFAULTS = {
      :config_file  => 'config.rb',
      :data_path    => 'data',
      :log_path     => 'log',
      :cache_path   => '.cache',
      :tmp_path     => '.tmp'
    }

    class << self
      attr_reader :user, :root_path, :config_file,
                  :data_path, :log_path, :cache_path, :tmp_path

      ##
      # Setup required paths based on the given options
      def update(options = {})
        root_path = options[:root_path].to_s.strip
        new_root = root_path.empty? ? false : set_root_path(root_path)

        DEFAULTS.each do |name, ending|
          set_path_variable(name, options[name], ending, new_root)
        end
      end

      ##
      # Tries to find and load the configuration file
      def load_config!
        unless File.exist?(@config_file)
          raise Errors::Config::NotFoundError,
              "Could not find configuration file: '#{@config_file}'."
        end

        module_eval(File.read(@config_file), @config_file)
      end

      private

      ##
      # Sets the @root_path to the given +path+ and returns it.
      # Raises an error if the given +path+ does not exist.
      def set_root_path(path)
        # allows #reset! to set the default @root_path,
        # then use #update to set all other paths,
        # without requiring that @root_path exist.
        return @root_path if path == @root_path

        path = File.expand_path(path)
        unless File.directory?(path)
          raise Errors::Config::NotFoundError, <<-EOS
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
        if path.empty?
          new_path = File.join(root_path, ending) if root_path
        else
          new_path = File.expand_path(path)
          unless path == new_path
            new_path = File.join(root_path, path) if root_path
          end
        end
        instance_variable_set(:"@#{name}", new_path) if new_path
      end

      ##
      # Set default values for accessors
      def reset!
        @user      = ENV['USER'] || Etc.getpwuid.name
        @root_path = File.join(File.expand_path(ENV['HOME'] || ''), 'Backup')
        update(:root_path => @root_path)
      end

      ##
      # List the available database, storage, syncer, compressor, encryptor
      # and notifier constants. These are used to dynamically define these
      # constant names inside Backup::Config to provide a nicer configuration
      # file DSL syntax to the users. Adding existing constants to the arrays
      # below will enable the user to use a constant instead of a string.
      # Nested namespaces are represented using Hashs. Deep nesting supported.
      #
      # Example, instead of:
      #  database "MySQL" do |mysql|
      #  sync_with "RSync::Local" do |rsync|
      #
      # You can do:
      #  database MySQL do |mysql|
      #  sync_with RSync::Local do |rsync|
      #
      def add_dsl_constants!
        create_modules(
          self,
          [ # Databases
            ['MySQL', 'PostgreSQL', 'MongoDB', 'Redis', 'Riak'],
            # Storages
            ['S3', 'CloudFiles', 'Ninefold', 'Dropbox', 'FTP',
            'SFTP', 'SCP', 'RSync', 'Local'],
            # Compressors
            ['Gzip', 'Bzip2', 'Custom', 'Pbzip2', 'Lzma'],
            # Encryptors
            ['OpenSSL', 'GPG'],
            # Syncers
            [
              { 'Cloud' => ['CloudFiles', 'S3'] },
              { 'RSync' => ['Push', 'Pull', 'Local'] }
            ],
            # Notifiers
            ['Mail', 'Twitter', 'Campfire', 'Prowl', 'Hipchat', 'Pushover']
          ]
        )
      end

      def create_modules(scope, names)
        names.flatten.each do |name|
          if name.is_a?(Hash)
            name.each do |key, val|
              create_modules(get_or_create_empty_module(scope, key), [val])
            end
          else
            get_or_create_empty_module(scope, name)
          end
        end
      end

      def get_or_create_empty_module(scope, const)
        if scope.const_defined?(const)
          scope.const_get(const)
        else
          scope.const_set(const, Module.new)
        end
      end
    end

    ##
    # Add the DSL constants and set default values for accessors when loaded.
    add_dsl_constants!
    reset!
  end

  ##
  # Warn user of deprecated Backup::CONFIG_FILE constant reference
  # in older config.rb files and return the proper Config.config_file value.
  class << self
    def const_missing(const)
      if const.to_s == 'CONFIG_FILE'
        Logger.warn Errors::ConfigError.new(<<-EOS)
          Configuration File Upgrade Needed
          Your configuration file, located at #{ Config.config_file }
          needs to be upgraded for this version of Backup.
          The reference to 'Backup::CONFIG_FILE' in your current config.rb file
          has been deprecated and needs to be replaced with 'Config.config_file'.
          You may update this reference in your config.rb manually,
          or generate a new config.rb using 'backup generate:config'.
          * Note: if you have global configuration defaults set in config.rb,
          be sure to transfer them to your new config.rb, should you choose
          to generate a new config.rb file.
        EOS
        return Config.config_file
      end
      super
    end
  end
end
