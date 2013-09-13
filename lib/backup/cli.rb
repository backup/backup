# encoding: utf-8

##
# Build the Backup Command Line Interface using Thor
module Backup
  class CLI < Thor
    class Error < Backup::Error; end
    class FatalError < Backup::FatalError; end

    ##
    # [Perform]
    #
    # The only required option is the --trigger [-t].
    # If --config-file, --data-path, --cache-path, --tmp-path aren't specified
    # they will fallback to defaults defined in Backup::Config.
    # If --root-path is given, it will be used as the base path for our defaults,
    # as well as the base path for any option specified as a relative path.
    # Any option given as an absolute path will be used "as-is".
    #
    # This command will exit with one of the following status codes:
    #
    #   0: All triggers were successful and no warnings were issued.
    #   1: All triggers were successful, but some had warnings.
    #   2: All triggers were processed, but some failed.
    #   3: A fatal error caused Backup to exit.
    #      Some triggers may not have been processed.
    #
    # If the --check option is given, `backup check` will be run
    # and no triggers will be performed.
    desc 'perform', "Performs the backup for the specified trigger(s)."

    long_desc <<-EOS.gsub(/^ +/, '')
      Performs the backup for the specified trigger(s).

      You may perform multiple backups by providing multiple triggers,
      separated by commas. Each will run in the order specified.

      $ backup perform --triggers backup1,backup2,backup3,backup4

      --root-path may be an absolute path or relative to the current directory.

      To use the current directory, use: `--root-path .`

      Relative paths given for --config-file, --data-path, --log-path,
      --cache-path and --tmp-path will be relative to --root-path.

      Console log output may be forced using --no-quiet.

      Logging to file or syslog may be disabled using --no-logfile or --no-syslog
      respectively. This will override logging options set in `config.rb`.
    EOS

    method_option :trigger,
                  :aliases  => ['-t', '--triggers'],
                  :required => true,
                  :type     => :string,
                  :desc     => "Triggers to perform. e.g. 'trigger_a,trigger_b'"

    method_option :config_file,
                  :aliases  => '-c',
                  :type     => :string,
                  :default  => '',
                  :desc     => 'Path to your config.rb file.'

    method_option :root_path,
                  :aliases  => '-r',
                  :type     => :string,
                  :default  => '',
                  :desc     => 'Root path to base all relative path on.'

    method_option :data_path,
                  :aliases  => '-d',
                  :type     => :string,
                  :default  => '',
                  :desc     => 'Path to store storage cycling data.'

    method_option :log_path,
                  :aliases  => '-l',
                  :type     => :string,
                  :default  => '',
                  :desc     => "Path to store Backup's log file."

    method_option :cache_path,
                  :type     => :string,
                  :default  => '',
                  :desc     => "Path to store Dropbox's cached authorization."

    method_option :tmp_path,
                  :type     => :string,
                  :default  => '',
                  :desc     => 'Path to store temporary data during the backup.'

    # Note that :quiet, :syslog and :logfile are specified as :string types,
    # so the --no-<option> usage will set the value to nil instead of false.
    method_option :quiet,
                  :aliases  => '-q',
                  :type     => :string,
                  :default  => false,
                  :banner   => '',
                  :desc     => 'Disable console log output.'

    method_option :syslog,
                  :type     => :string,
                  :default  => false,
                  :banner   => '',
                  :desc     => 'Enable logging to syslog.'

    method_option :logfile,
                  :type     => :string,
                  :default  => true,
                  :banner   => '',
                  :desc     => "Enable Backup's log file."

    method_option :check,
                  :type     => :boolean,
                  :default  => false,
                  :desc     => 'Check configuration for errors or warnings.'

    def perform
      check if options[:check] # this will exit()

      models = nil
      begin
        # Set logger options
        opts = options
        Logger.configure do
          console.quiet     = opts[:quiet]
          logfile.enabled   = opts[:logfile]
          logfile.log_path  = opts[:log_path]
          syslog.enabled    = opts[:syslog]
        end

        # Update Config variables
        # (config_file, root_path, data_path, cache_path, tmp_path)
        Config.update(options)

        # Load the user's +config.rb+ file (and all their Models).
        # May update Logger (and Config) options.
        Config.load_config!

        # Identify all Models to be run for the given +triggers+.
        triggers = options[:trigger].split(',').map(&:strip)
        models = triggers.map {|trigger|
          Model.find_by_trigger(trigger)
        }.flatten.uniq

        raise Error, "No Models found for trigger(s) " +
            "'#{ triggers.join(',') }'." if models.empty?

        # Finalize Logger and begin real-time logging.
        Logger.start!

      rescue Exception => err
        Logger.error Error.wrap(err)
        # Logger configuration will be ignored
        # and messages will be output to the console only.
        Logger.abort!
        exit(3)
      end

      until models.empty?
        model = models.shift
        model.perform!

        case model.exit_status
        when 1
          warnings = true
        when 2
          errors = true
          unless models.empty?
            Logger.info Error.new(<<-EOS)
              Backup will now continue...
              The following triggers will now be processed:
              (#{ models.map {|m| m.trigger }.join(', ') })
            EOS
          end
        when 3
          fatal = true
          unless models.empty?
            Logger.error FatalError.new(<<-EOS)
              Backup will now exit.
              The following triggers will not be processed:
              (#{ models.map {|m| m.trigger }.join(', ') })
            EOS
          end
        end

        model.notifiers.each(&:perform!)
        exit(3) if fatal
        Logger.clear!
      end

      exit(errors ? 2 : 1) if errors || warnings
    end

    ##
    # [Check]
    #
    # Loads the user's `config.rb` (and all Model files) and reports any Errors
    # or Warnings. This is primarily for checking for syntax errors, missing
    # dependencies and deprecation warnings.
    #
    # This may also be invoked using the `--check` option to `backup perform`.
    #
    # This command only requires `Config.config_file` to be correct.
    # All other Config paths are irrelevant.
    #
    # All output will be sent to the console only.
    # Logger options will be ignored.
    #
    # If successful, this method with exit(0).
    # If there are Errors or Warnings, it will exit(1).
    desc 'check', 'Check for configuration errors or warnings'

    long_desc <<-EOS.gsub(/^ +/, '')
      Loads your 'config.rb' file and all models and reports any
      errors or warnings with your configuration, including missing
      dependencies and the use of any deprecated settings.
    EOS

    method_option :config_file,
                  :aliases  => '-c',
                  :type     => :string,
                  :default  => '',
                  :desc     => "Path to your config.rb file."

    def check
      begin
        Config.update(options)
        Config.load_config!
      rescue Exception => err
        Logger.error Error.wrap(err)
      end

      if Logger.has_warnings? || Logger.has_errors?
        Logger.error 'Configuration Check Failed.'
        exit_code = 1
      else
        Logger.info 'Configuration Check Succeeded.'
        exit_code = 0
      end

      Logger.abort!
      exit(exit_code)
    end

    ##
    # [Generate:Model]
    # Generates a model configuration file based on the arguments passed in.
    # For example:
    #   $ backup generate:model --trigger my_backup --databases='mongodb'
    # will generate a pre-populated model with a base MongoDB setup
    desc 'generate:model', "Generates a Backup model file."

    long_desc <<-EOS.gsub(/^ +/, '')
      Generates a Backup model file.

      '--config-path' is the path to the *directory* where 'config.rb' is located.

      The model file will be created as '<config_path>/models/<trigger>.rb'

      The default location would be:

      #{ Config.root_path }/models/
    EOS

    method_option :trigger,
                  :aliases  => '-t',
                  :required => true,
                  :type     => :string,
                  :desc     => 'Trigger name for the Backup model'

    method_option :config_path,
                  :type     => :string,
                  :desc     => 'Path to your Backup configuration directory'

    # options with their available values
    %w{ databases storages syncers
        encryptors compressors notifiers }.map(&:to_sym).each do |name|
      path = File.join(Backup::TEMPLATE_PATH, 'cli', name.to_s[0..-2])
      method_option name, :type => :string, :desc =>
          "(#{Dir[path + '/*'].sort.map {|p| File.basename(p) }.join(', ')})"
    end

    method_option :archives,
                  :type     => :boolean,
                  :desc     => 'Model will include tar archives.'
    method_option :splitter,
                  :type     => :boolean,
                  :default  => true,
                  :desc     => "Use `--no-splitter` to disable"

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

      if File.file?(config_path)
        abort('--config-path should be a directory, not a file.')
      end

      FileUtils.mkdir_p(models_path)
      if Helpers.overwrite?(model)
        File.open(model, 'w') do |file|
          file.write(
            Backup::Template.new({:options => opts}).result("cli/model.erb")
          )
        end
        puts "Generated model file: '#{ model }'."
      end

      unless File.exist?(config)
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

    long_desc <<-EOS.gsub(/^ +/, '')
      Path to your Backup configuration directory.

      Default path would be:

      #{ Config.root_path }
    EOS

    method_option :config_path,
                  :type => :string,
                  :desc => 'Path to your Backup configuration directory.'

    define_method 'generate:config' do
      config_path = options[:config_path] ?
          File.expand_path(options[:config_path]) : Config.root_path
      config = File.join(config_path, "config.rb")

      FileUtils.mkdir_p(config_path)
      if Helpers.overwrite?(config)
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
        password = options[:password_file].empty? ? '' :
            "-pass file:#{ options[:password_file] }"
        salt     = options[:salt] ? '-salt' : ''

        Helpers.exec!(
          "openssl aes-256-cbc -d #{ base64 } #{ password } #{ salt } " +
          "-in '#{ options[:in] }' -out '#{ options[:out] }'"
        )
      when 'gpg'
        Helpers.exec!(
          "gpg -o '#{ options[:out] }' -d '#{ options[:in] }'"
        )
      else
        puts "Unknown encryptor: #{ options[:encryptor] }"
        puts "Use either 'openssl' or 'gpg'."
      end
    end

    ##
    # [Version]
    # Returns the current version of the Backup gem
    map '-v' => :version
    desc 'version', 'Display installed Backup version'
    def version
      puts "Backup #{ Backup::VERSION }"
    end

    # This is to avoid Thor's warnings when stubbing methods on the Thor class.
    module Helpers
      class << self

        def overwrite?(path)
          return true unless File.exist?(path)

          $stderr.print "A file already exists at '#{ path }'.\n" +
                        "Do you want to overwrite? [y/n] "
          /^[Yy]/ =~ $stdin.gets
        end

        def exec!(cmd)
          puts "Launching: #{ cmd }"
          exec(cmd)
        end

      end
    end

  end
end
