# encoding: utf-8

##
# Build the Backup Command Line Interface using Thor
module Backup
  module CLI
    class Utility < Thor
      include Thor::Actions

      ##
      # [Perform]
      # Performs the backup process. The only required option is the --trigger [-t].
      # If the other options (--config-file, --data-path, --cache--path, --tmp-path) aren't specified
      # they will fallback to the (good) defaults
      #
      # If --root-path is given, it will be used as the base path for our defaults,
      # as well as the base path for any option specified as a relative path.
      # Any option given as an absolute path will be used "as-is".
      method_option :trigger,         :type => :string,  :required => true, :aliases => ['-t', '--triggers']
      method_option :config_file,     :type => :string,  :default => '',    :aliases => '-c'
      method_option :root_path,       :type => :string,  :default => '',    :aliases => '-r'
      method_option :data_path,       :type => :string,  :default => '',    :aliases => '-d'
      method_option :log_path,        :type => :string,  :default => '',    :aliases => '-l'
      method_option :cache_path,      :type => :string,  :default => ''
      method_option :tmp_path,        :type => :string,  :default => ''
      method_option :quiet,           :type => :boolean, :default => false, :aliases => '-q'
      desc 'perform', "Performs the backup for the specified trigger.\n" +
                      "You may perform multiple backups by providing multiple triggers, separated by commas.\n\n" +
                      "Example:\n\s\s$ backup perform --triggers backup1,backup2,backup3,backup4\n\n" +
                      "This will invoke 4 backups, and they will run in the order specified (not asynchronous)."
      def perform
        ##
        # Silence Backup::Logger from printing to STDOUT, if --quiet was specified
        Logger.quiet = options[:quiet]

        ##
        # Update Config variables based on the given options
        Config.update(options)

        ##
        # Ensure the :log_path, :cache_path and :tmp_path are created
        # if they do not yet exist
        [Config.log_path, Config.cache_path, Config.tmp_path].each do |path|
          FileUtils.mkdir_p(path)
        end

        ##
        # Load the configuration file
        Config.load_config!

        ##
        # Truncate log file if needed
        Logger.truncate!

        ##
        # Prepare all trigger names by splitting them by ','
        # and finding trigger names matching wildcard
        triggers = options[:trigger].split(",")
        triggers.map!(&:strip).map! {|t|
          t.include?('*') ? Model.find_matching(t).map(&:trigger) : t
        }.flatten!

        ##
        # Process each trigger
        triggers.each do |trigger|
          ##
          # Find the model for this trigger
          # Will raise an error if not found
          model = Model.find(trigger)

          ##
          # Prepare and Perform the backup
          model.prepare!
          model.perform!

          ##
          # Clear the Log Messages for the next potential run
          Logger.clear!
        end

      rescue => err
        Logger.error Errors::CLIError.wrap(err)
        exit(1)
      end

      ##
      # [Generate:Model]
      # Generates a model configuration file based on the arguments passed in.
      # For example:
      #   $ backup generate:model --trigger my_backup --databases='mongodb'
      # will generate a pre-populated model with a base MongoDB setup
      desc 'generate:model', "Generates a Backup model file\n\n" +
          "Note:\n" +
          "\s\s'--config-path' is the path to the directory where 'config.rb' is located.\n" +
          "\s\sThe model file will be created as '<config_path>/models/<trigger>.rb'\n" +
          "\s\sDefault: #{Config.root_path}\n"

      method_option :trigger,     :type => :string, :required => true
      method_option :config_path, :type => :string,
                    :desc => 'Path to your Backup configuration directory'

      # options with their available values
      %w{ databases storages syncers
          encryptors compressors notifiers }.map(&:to_sym).each do |name|
        path = File.join(Backup::TEMPLATE_PATH, 'cli', 'utility', name.to_s[0..-2])
        method_option name, :type => :string, :desc =>
            "(#{Dir[path + '/*'].sort.map {|p| File.basename(p) }.join(', ')})"
      end

      method_option :archives,    :type => :boolean
      method_option :splitter,    :type => :boolean, :default => true,
                    :desc => "use `--no-splitter` to disable"

      define_method "generate:model" do
        opts = options.merge(
          :trigger      =>  options[:trigger].gsub(/[\W\s]/, '_'),
          :config_path  =>  options[:config_path] ?
                            File.expand_path(options[:config_path]) : nil
        )
        config_path    = opts[:config_path] || Config.root_path
        models_path    = File.join(config_path, "models")
        config         = File.join(config_path, "config.rb")
        model          = File.join(models_path, "#{opts[:trigger]}.rb")

        FileUtils.mkdir_p(models_path)
        if overwrite?(model)
          File.open(model, 'w') do |file|
            file.write(Backup::Template.new({:options => opts}).
                       result("cli/utility/model.erb"))
          end
          puts "Generated model file: '#{ model }'."
        end

        if not File.exist?(config)
          File.open(config, "w") do |file|
            file.write(Backup::Template.new.result("cli/utility/config"))
          end
          puts "Generated configuration file: '#{ config }'."
        end
      end

      ##
      # [Generate:Config]
      # Generates the main configuration file
      desc 'generate:config', 'Generates the main Backup bootstrap/configuration file'
      method_option :config_path, :type => :string,
                    :desc => 'Path to your Backup configuration directory'
      define_method 'generate:config' do
        config_path = options[:config_path] ?
            File.expand_path(options[:config_path]) : Config.root_path
        config = File.join(config_path, "config.rb")

        FileUtils.mkdir_p(config_path)
        if overwrite?(config)
          File.open(config, "w") do |file|
            file.write(Backup::Template.new.result("cli/utility/config"))
          end
          puts "Generated configuration file: '#{ config }'."
        end
      end

      ##
      # [Decrypt]
      # Shorthand for decrypting encrypted files
      desc 'decrypt', 'Decrypts encrypted files'
      method_option :encryptor,     :type => :string,  :required => true
      method_option :in,            :type => :string,  :required => true
      method_option :out,           :type => :string,  :required => true
      method_option :base64,        :type => :boolean, :default  => false
      method_option :password_file, :type => :string,  :default  => ''
      method_option :salt,          :type => :boolean, :default  => false
      def decrypt
        case options[:encryptor].downcase
        when 'openssl'
          base64   = options[:base64] ? '-base64' : ''
          password = options[:password_file].empty? ? '' : "-pass file:#{options[:password_file]}"
          salt     = options[:salt] ? '-salt' : ''
          %x[openssl aes-256-cbc -d #{base64} #{password} #{salt} -in '#{options[:in]}' -out '#{options[:out]}']
        when 'gpg'
          %x[gpg -o '#{options[:out]}' -d '#{options[:in]}']
        else
          puts "Unknown encryptor: #{options[:encryptor]}"
          puts "Use either 'openssl' or 'gpg'."
        end
      end

      ##
      # [Dependencies]
      # Returns a list of Backup's dependencies
      desc 'dependencies', 'Display the list of dependencies for Backup, check the installation status, or install them through Backup.'
      method_option :install, :type => :string
      method_option :list,    :type => :boolean
      method_option :installed, :type => :string
      def dependencies
        unless options.any?
          puts
          puts "To display a list of available dependencies, run:\n\n"
          puts "  backup dependencies --list"
          puts
          puts "To install one of these dependencies (with the correct version), run:\n\n"
          puts "  backup dependencies --install <name>"
          puts
          puts "To check if a dependency is already installed, run:\n\n"
          puts "  backup dependencies --installed <name>"
          exit
        end

        if options[:list]
          Backup::Dependency.all.each do |name, gemspec|
            puts
            puts name
            puts "--------------------------------------------------"
            puts "version:       #{gemspec[:version]}"
            puts "lib required:  #{gemspec[:require]}"
            puts "used for:      #{gemspec[:for]}"
          end
        end

        if options[:install]
          puts
          puts "Installing \"#{options[:install]}\" version \"#{Backup::Dependency.all[options[:install]][:version]}\".."
          puts "If this doesn't work, please issue the following command yourself:\n\n"
          puts "  gem install #{options[:install]} -v '#{Backup::Dependency.all[options[:install]][:version]}'\n\n"
          puts "Please wait..\n\n"
          puts %x[gem install #{options[:install]} -v '#{Backup::Dependency.all[options[:install]][:version]}']
        end

        if options[:installed]
          puts %x[gem list -i -v '#{Backup::Dependency.all[options[:installed]][:version]}' #{options[:installed]}]
        end
      end

      ##
      # [Version]
      # Returns the current version of the Backup gem
      map '-v' => :version
      desc 'version', 'Display installed Backup version'
      def version
        puts "Backup #{Backup::Version.current}"
      end

      private

      ##
      # Helper method for asking the user if he/she wants to overwrite the file
      def overwrite?(path)
        if File.exist?(path)
          return yes? "A file already exists at '#{ path }'. Do you want to overwrite? [y/n]"
        end
        true
      end

    end
  end
end
