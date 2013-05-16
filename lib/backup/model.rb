# encoding: utf-8

module Backup
  class Model
    class << self
      ##
      # The Backup::Model.all class method keeps track of all the models
      # that have been instantiated. It returns the @all class variable,
      # which contains an array of all the models
      def all
        @all ||= []
      end

      ##
      # Return an Array of Models matching the given +trigger+.
      def find_by_trigger(trigger)
        trigger = trigger.to_s
        if trigger.include?('*')
          regex = /^#{ trigger.gsub('*', '(.*)') }$/
          all.select {|model| regex =~ model.trigger }
        else
          all.select {|model| trigger == model.trigger }
        end
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
    # Result of this model's backup process.
    #
    # 0 = Job was successful
    # 1 = Job was successful, but issued warnings
    # 2 = Job failed, additional triggers may be performed
    # 3 = Job failed, additional triggers will not be performed
    attr_reader :exit_status

    ##
    # When #exit_status is 2 or 3, this is the Exception that caused the failure.
    attr_reader :exception

    ##
    # Takes a trigger, label and the configuration block.
    # After the instance has evaluated the configuration block
    # to configure the model, it will be appended to Model.all
    def initialize(trigger, label, &block)
      @trigger = trigger.to_s
      @label   = label.to_s
      @package = Package.new(self)

      @databases  = []
      @archives   = []
      @storages   = []
      @notifiers  = []
      @syncers    = []

      instance_eval(&block) if block_given?

      # trigger all defined databases to generate their #dump_filename
      # so warnings may be logged if `backup perform --check` is used
      databases.each {|db| db.send(:dump_filename) }

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
    def database(name, database_id = nil, &block)
      @databases << get_class_from_scope(Database, name).
          new(self, database_id, &block)
    end

    ##
    # Adds a storage method to the array of storage
    # methods to use during the backup process
    def store_with(name, storage_id = nil, &block)
      @storages << get_class_from_scope(Storage, name).
          new(self, storage_id, &block)
    end

    ##
    # Adds a syncer method to the array of syncer
    # methods to use during the backup process
    def sync_with(name, syncer_id = nil, &block)
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
      @syncers << get_class_from_scope(Syncer, name).new(syncer_id, &block)
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
      @time = package.time = @started_at.strftime("%Y.%m.%d.%H.%M.%S")
      log!(:started)

      procedures.each do |procedure|
        (procedure.call; next) if procedure.is_a?(Proc)
        procedure.each(&:perform!)
      end

      syncers.each(&:perform!)

    rescue Exception => err
      @exception = err

    ensure
      set_exit_status
      log!(:finished)
    end

    private

    ##
    # Returns an array of procedures
    def procedures
      return [] unless databases.any? || archives.any?

      [lambda { prepare! }, databases, archives,
       lambda { package! }, storages, lambda { clean! }]
    end

    ##
    # Clean any temporary files and/or package files left over
    # from the last time this model/trigger was performed.
    # Logs warnings if files exist and are cleaned.
    def prepare!
      Cleaner.prepare(self)
    end

    ##
    # After all the databases and archives have been dumped and stored,
    # these files will be bundled in to a .tar archive (uncompressed),
    # which may be optionally Encrypted and/or Split into multiple "chunks".
    # All information about this final archive is stored in the @package.
    # Once complete, the temporary folder used during packaging is removed.
    def package!
      Packager.package!(self)
      Cleaner.remove_packaging(self)
    end

    ##
    # Removes the final package file(s) once all configured Storages have run.
    def clean!
      Cleaner.remove_package(package)
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

    def set_exit_status
      @exit_status = if exception
        exception.is_a?(StandardError) ? 2 : 3
      else
        Logger.has_warnings? ? 1 : 0
      end
    end

    ##
    # Logs messages when the backup starts, finishes or fails
    def log!(action)
      case action
      when :started
        Logger.info "Performing Backup for '#{label} (#{trigger})'!\n" +
            "[ backup #{ VERSION } : #{ RUBY_DESCRIPTION } ]"

      when :finished
        if exit_status > 1
          err = Errors::ModelError.wrap(exception, <<-EOS)
            Backup for #{label} (#{trigger}) Failed!
            An Error occured which has caused this Backup to abort before completion.
          EOS
          Logger.error err
          Logger.error "\nBacktrace:\n\s\s" + err.backtrace.join("\n\s\s") + "\n\n"

          Cleaner.warnings(self)
        else
          msg = "Backup for '#{ label } (#{ trigger })' " +
                "Completed %s in #{ elapsed_time }"
          if exit_status == 1
            Logger.warn msg % 'Successfully (with Warnings)'
          else
            Logger.info msg % 'Successfully'
          end
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
