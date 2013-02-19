# encoding: utf-8

##
# Build the Backup Command Line Interface using Thor
module Backup
  class CLI < Thor
    include Thor::Actions

    ##
    # [Perform]
    # Performs the backup process. The only required option is the --trigger [-t].
    # If the other options (--config-file, --data-path, --cache-path, --tmp-path) aren't specified
    # they will fallback to the (good) defaults
    #
    # If --root-path is given, it will be used as the base path for our defaults,
    # as well as the base path for any option specified as a relative path.
    # Any option given as an absolute path will be used "as-is".
    desc 'perform', "Performs the backup for the specified trigger(s)."
    long_desc "Performs the backup for the specified trigger(s).\n\n" +
              "You may perform multiple backups by providing multiple triggers, separated by commas.\n\n" +
              "Example:\n\s\s$ backup perform --triggers backup1,backup2,backup3,backup4\n\n" +
              "This will invoke 4 backups, and they will run in the order specified (not asynchronous).\n\n" +
              "\n\n" +
              "--root-path may be an absolute path or relative to the current working directory.\n\n" +
              "To use the current directory, you can use: `--root-path .` (i.e. a period for the argument)"

    method_option :trigger,         :type => :string,  :required => true, :aliases => ['-t', '--triggers'],
                                    :desc => "Triggers to perform. e.g. 'trigger_a,trigger_b'"
    method_option :config_file,     :type => :string,  :default => '',    :aliases => '-c',
                                    :desc => "Path to your config.rb file. " +
                                              "Absolute, or relative to --root-path."
    method_option :root_path,       :type => :string,  :default => '',    :aliases => '-r',
                                    :desc => "Root path to base all relative path on. " +
                                              "Absolute or relative to current directory (#{Dir.pwd})."
    method_option :data_path,       :type => :string,  :default => '',    :aliases => '-d',
                                    :desc => "Path to store persisted data (storage 'keep' data). " +
                                              "Absolute, or relative to --root-path."
    method_option :log_path,        :type => :string,  :default => '',    :aliases => '-l',
                                    :desc => "Path to store Backup's log file. " +
                                              "Absolute, or relative to --root-path."
    method_option :cache_path,      :type => :string,  :default => '',
                                    :desc => "Path to store Dropbox's cached authorization. " +
                                              "Absolute, or relative to --root-path."
    method_option :tmp_path,        :type => :string,  :default => '',
                                    :desc => "Path to store temporary data during the backup process. " +
                                              "Absolute, or relative to --root-path."
    # Note that :quiet, :syslog and :logfile are specified as :string types,
    # so the --no-<option> usage will set the value to nil instead of false.
    method_option :quiet,           :type => :string,  :default => false, :aliases => '-q', :banner => '',
                                    :desc => "Disable console log output. " +
                                              "May be force enabled using --no-quiet."
    method_option :syslog,          :type => :string,  :default => false, :banner => '',
                                    :desc => "Enable logging to syslog. " +
                                              "May be forced disabled using --no-syslog."
    method_option :logfile,         :type => :string,  :default => true, :banner => '',
                                    :desc => "Enable Backup's log file. " +
                                              "May be forced disabled using --no-logfile."
    method_option :check,           :type => :boolean,  :default => false,
                                    :desc => "Check `config.rb` and all Model configuration for errors or warnings."

    def perform
      ##
      # Prepare to perform requested backup jobs.
      models = nil
      begin
        ##
        # Set logger options
        opts = options
        Logger.configure do
          console.quiet = opts[:quiet]
          logfile.enabled = opts[:logfile]
          logfile.log_path = opts[:log_path]
          syslog.enabled = opts[:syslog]
        end

        ##
        # Update Config variables
        # (config_file, root_path, data_path, cache_path, tmp_path)
        Config.update(options)

        ##
        # Ensure the :cache_path and :tmp_path are created
        # if they do not yet exist
        [Config.cache_path, Config.tmp_path].each do |path|
          FileUtils.mkdir_p(path)
        end

        ##
        # Load the user's +config.rb+ file (and all their Models).
        # May update Logger options.
        Config.load_config!

        ##
        # Identify all Models to be run for the given +triggers+.
        triggers = options[:trigger].split(',').map(&:strip)
        models = triggers.map {|trigger|
          Model.find_by_trigger(trigger)
        }.flatten.uniq

        if models.empty?
          raise Errors::CLIError,
              "No Models found for trigger(s) '#{triggers.join(',')}'."
        end

        if options[:check] && Logger.has_warnings?
          raise Errors::CLIError, 'Configuration Check has warnings.'
        end

        ##
        # Finalize Logger configuration and begin real-time logging.
        Logger.start!

      rescue => err
        Logger.error Errors::CLIError.wrap(err)
        Logger.error 'Configuration Check Failed.' if options[:check]
        # Logger configuration will be ignored
        # and messages will be output to the console only.
        Logger.abort!
        exit(1)
      end

      if options[:check]
        Logger.info 'Configuration Check Succeeded.'
      else
        ##
        # Perform the backup job for each Model found for the given triggers,
        # clearing the Logger after each job.
        #
        # Model#perform! handles all exceptions from this point,
        # as each model may fail and return here to allow others to run.
        models.each do |model|
          model.perform!
          Logger.clear!
        end
      end
    end

    ##
    # [Generate:Model]
    # Generates a model configuration file based on the arguments passed in.
    # For example:
    #   $ backup generate:model --trigger my_backup --databases='mongodb'
    # will generate a pre-populated model with a base MongoDB setup
    desc 'generate:model', "Generates a Backup model file."
    long_desc "Generates a Backup model file.\n\n" +
              "\s\sNote: '--config-path' is the path to the directory where 'config.rb' is located.\n\n" +
              "\s\sThe model file will be created as '<config_path>/models/<trigger>.rb'\n\n" +
              "\s\sDefault: #{Config.root_path}\n\n"

    method_option :trigger,     :type => :string, :required => true
    method_option :config_path, :type => :string,
                                :desc => 'Path to your Backup configuration directory'

    # options with their available values
    %w{ databases storages syncers
        encryptors compressors notifiers }.map(&:to_sym).each do |name|
      path = File.join(Backup::TEMPLATE_PATH, 'cli', name.to_s[0..-2])
      method_option name, :type => :string, :desc =>
          "(#{Dir[path + '/*'].sort.map {|p| File.basename(p) }.join(', ')})"
    end

    method_option :archives,    :type => :boolean
    method_option :splitter,    :type => :boolean, :default => true,
                                :desc => "use `--no-splitter` to disable"

    define_method "generate:model" do
      opts = options.merge(
        :trigger      =>  options[:trigger].gsub(/\W/, '_'),
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
          file.write(
            Backup::Template.new({:options => opts}).result("cli/model.erb")
          )
        end
        puts "Generated model file: '#{ model }'."
      end

      if not File.exist?(config)
        File.open(config, "w") do |file|
          file.write(Backup::Template.new.result("cli/config"))
        end
        puts "Generated configuration file: '#{ config }'."
      end
    end

    ##
    # [Generate:Config]
    # Generates the main configuration file
    desc 'generate:config', 'Generates the main Backup bootstrap/configuration file'
    method_option :config_path, :type => :string,
                                :desc => "Path to your Backup configuration directory. Default: #{Config.root_path}"

    define_method 'generate:config' do
      config_path = options[:config_path] ?
          File.expand_path(options[:config_path]) : Config.root_path
      config = File.join(config_path, "config.rb")

      FileUtils.mkdir_p(config_path)
      if overwrite?(config)
        File.open(config, "w") do |file|
          file.write(Backup::Template.new.result("cli/config"))
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
    desc 'dependencies', 'Display, Check or Install Dependencies for Backup.'
    long_desc 'Display the list of dependencies for Backup, check the installation status, or install them through Backup.'
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
