# encoding: utf-8

module Backup
  class Model
    include Backup::CLI::Helpers

    class << self
      ##
      # The Backup::Model.all class method keeps track of all the models
      # that have been instantiated. It returns the @all class variable,
      # which contains an array of all the models
      def all
        @all ||= []
      end

      ##
      # Return the first model matching +trigger+.
      # Raises Errors::MissingTriggerError if no matches are found.
      def find(trigger)
        trigger = trigger.to_s
        all.each do |model|
          return model if model.trigger == trigger
        end
        raise Errors::Model::MissingTriggerError,
            "Could not find trigger '#{trigger}'."
      end

      ##
      # Find and return an Array of all models matching +trigger+
      # Used to match triggers using a wildcard (*)
      def find_matching(trigger)
        regex = /^#{ trigger.to_s.gsub('*', '(.*)') }$/
        all.select {|model| regex =~ model.trigger }
      end
    end

    ##
    # The trigger (stored as a String) is used as an identifier
    # for initializing the backup process
    attr_reader :trigger

    ##
    # The label (stored as a String) is used for a more friendly user output
    attr_reader :label

    ##
    # The databases attribute holds an array of database objects
    attr_reader :databases

    ##
    # The archives attr_accessor holds an array of archive objects
    attr_reader :archives

    ##
    # The notifiers attr_accessor holds an array of notifier objects
    attr_reader :notifiers

    ##
    # The storages attribute holds an array of storage objects
    attr_reader :storages

    ##
    # The syncers attribute holds an array of syncer objects
    attr_reader :syncers

    ##
    # Holds the configured Compressor
    attr_reader :compressor

    ##
    # Holds the configured Encryptor
    attr_reader :encryptor

    ##
    # Holds the configured Splitter
    attr_reader :splitter

    ##
    # The final backup Package this model will create.
    attr_reader :package

    ##
    # The time when the backup initiated (in format: 2011.02.20.03.29.59)
    attr_reader :time

    ##
    # Hooks which can be run before or after the backup process
    attr_reader :hooks

    ##
    # Takes a trigger, label and the configuration block.
    # After the instance has evaluated the configuration block
    # to configure the model, it will be appended to Model.all
    def initialize(trigger, label, &block)
      @trigger = trigger.to_s
      @label   = label.to_s

      # default noop hooks
      @hooks   = Hooks.new(self)

      procedure_instance_variables.each do |variable|
        instance_variable_set(variable, Array.new)
      end

      instance_eval(&block) if block_given?
      Model.all << self
    end

    ##
    # Adds an archive to the array of archives
    # to store during the backup process
    def archive(name, &block)
      @archives << Archive.new(self, name, &block)
    end

    ##
    # Adds a database to the array of databases
    # to dump during the backup process
    def database(name, &block)
      @databases << get_class_from_scope(Database, name).new(self, &block)
    end

    ##
    # Adds a storage method to the array of storage
    # methods to use during the backup process
    def store_with(name, storage_id = nil, &block)
      @storages << get_class_from_scope(Storage, name).new(self, storage_id, &block)
    end

    ##
    # Adds a syncer method to the array of syncer
    # methods to use during the backup process
    def sync_with(name, &block)
      ##
      # Warn user of DSL changes
      case name.to_s
      when 'Backup::Config::RSync'
        Logger.warn Errors::ConfigError.new(<<-EOS)
          Configuration Update Needed for Syncer::RSync
          The RSync Syncer has been split into three separate modules:
          RSync::Local, RSync::Push and RSync::Pull
          Please update your configuration.
          i.e. 'sync_with RSync' is now 'sync_with RSync::Push'
        EOS
        name = 'RSync::Push'
      when /(Backup::Config::S3|Backup::Config::CloudFiles)/
        syncer = $1.split('::')[2]
        Logger.warn Errors::ConfigError.new(<<-EOS)
          Configuration Update Needed for '#{ syncer }' Syncer.
          This Syncer is now referenced as Cloud::#{ syncer }
          i.e. 'sync_with #{ syncer }' is now 'sync_with Cloud::#{ syncer }'
        EOS
        name = "Cloud::#{ syncer }"
      end
      @syncers << get_class_from_scope(Syncer, name).new(&block)
    end

    ##
    # Adds a notifier to the array of notifiers
    # to use during the backup process
    def notify_by(name, &block)
      @notifiers << get_class_from_scope(Notifier, name).new(self, &block)
    end

    ##
    # Adds an encryptor to use during the backup process
    def encrypt_with(name, &block)
      @encryptor = get_class_from_scope(Encryptor, name).new(&block)
    end

    ##
    # Adds a compressor to use during the backup process
    def compress_with(name, &block)
      @compressor = get_class_from_scope(Compressor, name).new(&block)
    end

    ##
    # Run a block of ruby code before the backup process
    def before(&block)
      @hooks.before &block
    end

    ##
    # Run a block of ruby code after the backup process
    def after(&block)
      @hooks.after &block
    end

    ##
    # Adds a method that allows the user to configure this backup model
    # to use a Splitter, with the given +chunk_size+
    # The +chunk_size+ (in megabytes) will later determine
    # in how many chunks the backup needs to be split into
    def split_into_chunks_of(chunk_size)
      if chunk_size.is_a?(Integer)
        @splitter = Splitter.new(self, chunk_size)
      else
        raise Errors::Model::ConfigurationError, <<-EOS
          Invalid Chunk Size for Splitter
          Argument to #split_into_chunks_of() must be an Integer
        EOS
      end
    end

    ##
    # Ensure DATA_PATH and DATA_PATH/TRIGGER are created
    # if they do not yet exist
    #
    # Clean any temporary files and/or package files left over
    # from the last time this model/trigger was performed.
    # Logs warnings if files exist and are cleaned.
    def prepare!
      FileUtils.mkdir_p(File.join(Config.data_path, trigger))
      Cleaner.prepare(self)
    end

    ##
    # Performs the backup process
    ##
    # [Databases]
    # Runs all (if any) database objects to dump the databases
    ##
    # [Archives]
    # Runs all (if any) archive objects to package all their
    # paths in to a single tar file and places it in the backup folder
    ##
    # [Packaging]
    # After all the database dumps and archives are placed inside
    # the folder, it'll make a single .tar package (archive) out of it
    ##
    # [Encryption]
    # Optionally encrypts the packaged file with the configured encryptor
    ##
    # [Compression]
    # Optionally compresses the each Archive and Database dump with the configured compressor
    ##
    # [Splitting]
    # Optionally splits the backup file in to multiple smaller chunks before transferring them
    ##
    # [Storages]
    # Runs all (if any) storage objects to store the backups to remote locations
    # and (if configured) it'll cycle the files on the remote location to limit the
    # amount of backups stored on each individual location
    ##
    # [Syncers]
    # Runs all (if any) sync objects to store the backups to remote locations.
    # A Syncer does not go through the process of packaging, compressing, encrypting backups.
    # A Syncer directly transfers data from the filesystem to the remote location
    ##
    # [Notifiers]
    # Runs all (if any) notifier objects when a backup proces finished with or without
    # any errors.
    ##
    # [Cleaning]
    # Once the final Packaging is complete, the temporary folder used will be removed.
    # Then, once all Storages have run, the final packaged files will be removed.
    # If any errors occur during the backup process, all temporary files will be left in place.
    # If the error occurs before Packaging, then the temporary folder (tmp_path/trigger)
    # will remain and may contain all or some of the configured Archives and/or Database dumps.
    # If the error occurs after Packaging, but before the Storages complete, then the final
    # packaged files (located in the root of tmp_path) will remain.
    # *** Important *** If an error occurs and any of the above mentioned temporary files remain,
    # those files *** will be removed *** before the next scheduled backup for the same trigger.
    #
    def perform!
      @started_at = Time.now
      @time = @started_at.strftime("%Y.%m.%d.%H.%M.%S")
      log!(:started)

      @hooks.perform!(:before)

      if databases.any? or archives.any?
        procedures.each do |procedure|
          (procedure.call; next) if procedure.is_a?(Proc)
          procedure.each(&:perform!)
        end
      end

      syncers.each(&:perform!)
      notifiers.each(&:perform!)

      @hooks.perform!(:after)

      log!(:finished)

    rescue Exception => err
      fatal = !err.is_a?(StandardError)

      err = Errors::ModelError.wrap(err, <<-EOS)
        Backup for #{label} (#{trigger}) Failed!
        An Error occured which has caused this Backup to abort before completion.
      EOS
      Logger.error err
      Logger.error "\nBacktrace:\n\s\s" + err.backtrace.join("\n\s\s") + "\n\n"

      Cleaner.warnings(self)

      if fatal
        Logger.error Errors::ModelError.new(<<-EOS)
          This Error was Fatal and Backup will now exit.
          If you have other Backup jobs (triggers) configured to run,
          they will not be processed.
        EOS
      else
        Logger.message Errors::ModelError.new(<<-EOS)
          If you have other Backup jobs (triggers) configured to run,
          Backup will now attempt to continue...
        EOS
      end

      notifiers.each do |n|
        begin
          n.perform!(true)
        rescue Exception; end
      end

      exit(1) if fatal
    end

    private

    ##
    # After all the databases and archives have been dumped and sorted,
    # these files will be bundled in to a .tar archive (uncompressed),
    # which may be optionally Encrypted and/or Split into multiple "chunks".
    # All information about this final archive is stored in the @package.
    # Once complete, the temporary folder used during packaging is removed.
    def package!
      @package = Package.new(self)
      Packager.package!(self)
      Cleaner.remove_packaging(self)
    end

    ##
    # Removes the final package file(s) once all configured Storages have run.
    def clean!
      Cleaner.remove_package(@package)
    end

    ##
    # Returns an array of procedures
    def procedures
      [databases, archives, lambda { package! }, storages, lambda { clean! }]
    end

    ##
    # Returns an Array of the names (String) of the procedure instance variables
    def procedure_instance_variables
      [:@databases, :@archives, :@storages, :@notifiers, :@syncers]
    end

    ##
    # Returns the class/model specified by +name+ inside of +scope+.
    # +scope+ should be a Class/Module.
    # +name+ may be Class/Module or String representation
    # of any namespace which exists under +scope+.
    #
    # The 'Backup::Config::' namespace is stripped from +name+,
    # since this is the namespace where we define module namespaces
    # for use with Model's DSL methods.
    #
    # Examples:
    #   get_class_from_scope(Backup::Database, 'MySQL')
    #     returns the class Backup::Database::MySQL
    #
    #   get_class_from_scope(Backup::Syncer, Backup::Config::RSync::Local)
    #     returns the class Backup::Syncer::RSync::Local
    #
    def get_class_from_scope(scope, name)
      klass = scope
      name = name.to_s.sub(/^Backup::Config::/, '')
      name.split('::').each do |chunk|
        klass = klass.const_get(chunk)
      end
      klass
    end

    ##
    # Logs messages when the backup starts and finishes
    def log!(action)
      case action
      when :started
        Logger.message "Performing Backup for '#{label} (#{trigger})'!\n" +
            "[ backup #{ Version.current } : #{ RUBY_DESCRIPTION } ]"

      when :finished
        msg = "Backup for '#{ label } (#{ trigger })' " +
              "Completed %s in #{ elapsed_time }"
        if Logger.has_warnings?
          Logger.warn msg % 'Successfully (with Warnings)'
        else
          Logger.message msg % 'Successfully'
        end
      end
    end

    ##
    # Returns a string representing the elapsed time since the backup started.
    def elapsed_time
      duration  = Time.now.to_i - @started_at.to_i
      hours     = duration / 3600
      remainder = duration - (hours * 3600)
      minutes   = remainder / 60
      seconds   = remainder - (minutes * 60)
      '%02d:%02d:%02d' % [hours, minutes, seconds]
    end

  end
end
