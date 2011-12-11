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
      # it'll fallback to the (good) defaults
      method_option :trigger,         :type => :string,  :aliases => ['-t', '--triggers'], :required => true
      method_option :config_file,     :type => :string,  :aliases => '-c'
      method_option :data_path,       :type => :string,  :aliases => '-d'
      method_option :log_path,        :type => :string,  :aliases => '-l'
      method_option :cache_path,      :type => :string
      method_option :tmp_path,        :type => :string
      method_option :quiet,           :type => :boolean, :aliases => '-q'
      desc 'perform', "Performs the backup for the specified trigger.\n" +
                      "You may perform multiple backups by providing multiple triggers, separated by commas.\n\n" +
                      "Example:\n\s\s$ backup perform --triggers backup1,backup2,backup3,backup4\n\n" +
                      "This will invoke 4 backups, and they will run in the order specified (not asynchronous)."
      def perform
        ##
        # Overwrites the CONFIG_FILE location, if --config-file was specified
        if options[:config_file]
          Backup.send(:remove_const, :CONFIG_FILE)
          Backup.send(:const_set, :CONFIG_FILE, options[:config_file])
        end

        ##
        # Overwrites the DATA_PATH location, if --data-path was specified
        if options[:data_path]
          Backup.send(:remove_const, :DATA_PATH)
          Backup.send(:const_set, :DATA_PATH, options[:data_path])
        end

        ##
        # Overwrites the LOG_PATH location, if --log-path was specified
        if options[:log_path]
          Backup.send(:remove_const, :LOG_PATH)
          Backup.send(:const_set, :LOG_PATH, options[:log_path])
        end

        ##
        # Overwrites the CACHE_PATH location, if --cache-path was specified
        if options[:cache_path]
          Backup.send(:remove_const, :CACHE_PATH)
          Backup.send(:const_set, :CACHE_PATH, options[:cache_path])
        end

        ##
        # Overwrites the TMP_PATH location, if --tmp-path was specified
        if options[:tmp_path]
          Backup.send(:remove_const, :TMP_PATH)
          Backup.send(:const_set, :TMP_PATH, options[:tmp_path])
        end

        ##
        # Silence Backup::Logger from printing to STDOUT, if --quiet was specified
        if options[:quiet]
          Logger.send(:const_set, :QUIET, options[:quiet])
        end

        ##
        # Ensure the CACHE_PATH, TMP_PATH and LOG_PATH are created if they do not yet exist
        Array.new([Backup::CACHE_PATH, Backup::TMP_PATH, Backup::LOG_PATH]).each do |path|
          FileUtils.mkdir_p(path)
        end

        ##
        # Prepare all trigger names by splitting them by ','
        # and finding trigger names matching wildcard
        triggers = options[:trigger].split(",")
        triggers.map!(&:strip).map!{ |t|
          t.include?(Backup::Finder::WILDCARD) ?
            Backup::Finder.new(t).matching : t
        }.flatten!

        ##
        # Process each trigger
        triggers.each do |trigger|

          ##
          # Defines the TRIGGER constant
          Backup.send(:const_set, :TRIGGER, trigger)

          ##
          # Define the TIME constants
          Backup.send(:const_set, :TIME, Time.now.strftime("%Y.%m.%d.%H.%M.%S"))

          ##
          # Ensure DATA_PATH and DATA_PATH/TRIGGER are created if they do not yet exist
          FileUtils.mkdir_p(File.join(Backup::DATA_PATH, Backup::TRIGGER))

          ##
          # Parses the backup configuration file and returns the model instance by trigger
          model = Backup::Finder.new(trigger).find

          ##
          # Runs the returned model
          Logger.message "Performing backup for #{model.label}!"
          model.perform!

          ##
          # Removes the TRIGGER constant
          Backup.send(:remove_const, :TRIGGER) if defined? Backup::TRIGGER

          ##
          # Removes the TIME constant
          Backup.send(:remove_const, :TIME) if defined? Backup::TIME

          ##
          # Reset the Backup::Model.current to nil for the next potential run
          Backup::Model.current = nil

          ##
          # Reset the Backup::Model.all to an empty array since this will be
          # re-filled during the next Backup::Finder.new(arg1, arg2).find
          Backup::Model.all = Array.new

          ##
          # Reset the Backup::Model.extension to 'tar' so it's at its
          # initial state when the next Backup::Model initializes
          Backup::Model.extension = 'tar'
        end

      rescue => err
        Logger.error Backup::Errors::CLIError.wrap(err)
        exit(1)
      end

      ##
      # [Generate]
      # Generates a configuration file based on the arguments passed in.
      # For example, running $ backup generate --databases='mongodb' will generate a pre-populated
      # configuration file with a base MongoDB setup
      desc 'generate:model', 'Generates a Backup model'
      method_option :name,        :type => :string, :required => true
      method_option :path,        :type => :string
      method_option :databases,   :type => :string
      method_option :storages,    :type => :string
      method_option :syncers,     :type => :string
      method_option :encryptors,  :type => :string
      method_option :compressors, :type => :string
      method_option :notifiers,   :type => :string
      method_option :archives,    :type => :boolean
      method_option :splitter,    :type => :boolean, :default => true, :desc => "use `--no-splitter` to disable"
      define_method "generate:model" do
        config_path    = options[:path] || Backup::PATH
        models_path    = File.join(config_path, "models")
        config         = File.join(config_path, "config.rb")
        model          = File.join(models_path, "#{options[:name]}.rb")

        if overwrite?(model)
          FileUtils.mkdir_p(models_path)
          File.open(model, 'w') do |file|
            file.write(Backup::Template.new({:options => options}).result("cli/utility/model.erb"))
          end
          puts "Generated model file in '#{ model }'."
        end

        if not File.exist?(config)
          File.open(config, "w") do |file|
            file.write(Backup::Template.new.result("cli/utility/config"))
          end
          puts "Generated configuration file in '#{ config }'."
        end
      end

      desc 'generate:config', 'Generates the main Backup bootstrap/configuration file'
      method_option :path, :type => :string
      define_method 'generate:config' do
        config_path = options[:path] || Backup::PATH
        config      = File.join(config_path, "config.rb")

        if overwrite?(config)
          File.open(config, "w") do |file|
            file.write(Backup::Template.new.result("cli/utility/config"))
          end
          puts "Generated configuration file in '#{ config }'"
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
          password = options[:password_file] ? "-pass file:#{options[:password_file]}" : ''
          salt     = options[:salt] ? '-salt' : ''
          %x[openssl aes-256-cbc -d #{base64} #{password} #{salt} -in '#{options[:in]}' -out '#{options[:out]}']
        when 'gpg'
          %x[gpg -o '#{options[:out]}' -d '#{options[:in]}']
        else
          puts "Unknown encryptor: #{options[:encryptor]}"
          puts "Use either 'openssl' or 'gpg'"
        end
      end

      ##
      # [Dependencies]
      # Returns a list of Backup's dependencies
      desc 'dependencies', 'Display the list of dependencies for Backup, or install them through Backup.'
      method_option :install, :type => :string
      method_option :list,    :type => :boolean
      def dependencies
        unless options.any?
          puts
          puts "To display a list of available dependencies, run:\n\n"
          puts "  backup dependencies --list"
          puts
          puts "To install one of these dependencies (with the correct version), run:\n\n"
          puts "  backup dependencies --install <name>"
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
