# encoding: utf-8

module Backup
  class Model
    class Error < Backup::Error; end
    class FatalError < Backup::FatalError; end

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

      # Allows users to create preconfigured models.
      def preconfigure(&block)
        @preconfigure ||= block
      end

      private

      # used for testing
      def reset!
        @all = @preconfigure = nil
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
    # Array of configured Database objects.
    attr_reader :databases

    ##
    # Array of configured Archive objects.
    attr_reader :archives

    ##
    # Array of configured Notifier objects.
    attr_reader :notifiers

    ##
    # Array of configured Storage objects.
    attr_reader :storages

    ##
    # Array of configured Syncer objects.
    attr_reader :syncers

    ##
    # The configured Compressor, if any.
    attr_reader :compressor

    ##
    # The configured Encryptor, if any.
    attr_reader :encryptor

    ##
    # The configured Splitter, if any.
    attr_reader :splitter

    ##
    # The final backup Package this model will create.
    attr_reader :package

    ##
    # The time when the backup initiated (in format: 2011.02.20.03.29.59)
    attr_reader :time

    ##
    # The time when the backup initiated (as a Time object)
    attr_reader :started_at

    ##
    # The time when the backup finished (as a Time object)
    attr_reader :finished_at

    ##
    # Result of this model's backup process.
    #
    # 0 = Job was successful
    # 1 = Job was successful, but issued warnings
    # 2 = Job failed, additional triggers may be performed
    # 3 = Job failed, additional triggers will not be performed
    attr_reader :exit_status

    ##
    # Exception raised by either a +before+ hook or one of the model's
    # procedures that caused the model to fail. An exception raised by an
    # +after+ hook would not be stored here. Therefore, it is possible for
    # this to be +nil+ even if #exit_status is 2 or 3.
    attr_reader :exception

    def initialize(trigger, label, &block)
      @trigger = trigger.to_s
      @label   = label.to_s
      @package = Package.new(self)

      @databases  = []
      @archives   = []
      @storages   = []
      @notifiers  = []
      @syncers    = []

      instance_eval(&self.class.preconfigure) if self.class.preconfigure
      instance_eval(&block) if block_given?

      # trigger all defined databases to generate their #dump_filename
      # so warnings may be logged if `backup perform --check` is used
      databases.each {|db| db.send(:dump_filename) }

      Model.all << self
    end

    ##
    # Adds an Archive. Multiple Archives may be added to the model.
    def archive(name, &block)
      @archives << Archive.new(self, name, &block)
    end

    ##
    # Adds an Database. Multiple Databases may be added to the model.
    def database(name, database_id = nil, &block)
      @databases << get_class_from_scope(Database, name).
          new(self, database_id, &block)
    end

    ##
    # Adds an Storage. Multiple Storages may be added to the model.
    def store_with(name, storage_id = nil, &block)
      @storages << get_class_from_scope(Storage, name).
          new(self, storage_id, &block)
    end

    ##
    # Adds an Syncer. Multiple Syncers may be added to the model.
    def sync_with(name, syncer_id = nil, &block)
      ##
      # Warn user of DSL changes
      case name.to_s
      when 'Backup::Config::RSync'
        Logger.warn Error.new(<<-EOS)
          Configuration Update Needed for Syncer::RSync
          The RSync Syncer has been split into three separate modules:
          RSync::Local, RSync::Push and RSync::Pull
          Please update your configuration.
          i.e. 'sync_with RSync' is now 'sync_with RSync::Push'
        EOS
        name = 'RSync::Push'
      when /(Backup::Config::S3|Backup::Config::CloudFiles)/
        syncer = $1.split('::')[2]
        Logger.warn Error.new(<<-EOS)
          Configuration Update Needed for '#{ syncer }' Syncer.
          This Syncer is now referenced as Cloud::#{ syncer }
          i.e. 'sync_with #{ syncer }' is now 'sync_with Cloud::#{ syncer }'
        EOS
        name = "Cloud::#{ syncer }"
      end
      @syncers << get_class_from_scope(Syncer, name).new(syncer_id, &block)
    end

    ##
    # Adds an Notifier. Multiple Notifiers may be added to the model.
    def notify_by(name, &block)
      @notifiers << get_class_from_scope(Notifier, name).new(self, &block)
    end

    ##
    # Adds an Encryptor. Only one Encryptor may be added to the model.
    # This will be used to encrypt the final backup package.
    def encrypt_with(name, &block)
      @encryptor = get_class_from_scope(Encryptor, name).new(&block)
    end

    ##
    # Adds an Compressor. Only one Compressor may be added to the model.
    # This will be used to compress each individual Archive and Database
    # stored within the final backup package.
    def compress_with(name, &block)
      @compressor = get_class_from_scope(Compressor, name).new(&block)
    end

    ##
    # Adds a Splitter to split the final backup package into multiple files.
    #
    # +chunk_size+ is specified in MiB and must be given as an Integer.
    # +suffix_length+ controls the number of characters used in the suffix
    # (and the maximum number of chunks possible).
    # ie. 1 (-a, -b), 2 (-aa, -ab), 3 (-aaa, -aab)
    def split_into_chunks_of(chunk_size, suffix_length = 2)
      if chunk_size.is_a?(Integer) && suffix_length.is_a?(Integer)
        @splitter = Splitter.new(self, chunk_size, suffix_length)
      else
        raise Error, <<-EOS
          Invalid arguments for #split_into_chunks_of()
          +chunk_size+ (and optional +suffix_length+) must be Integers.
        EOS
      end
    end

    ##
    # Defines a block of code to run before the model's procedures.
    #
    # Warnings logged within the before hook will elevate the model's
    # exit_status to 1 and cause warning notifications to be sent.
    #
    # Raising an exception will abort the model and cause failure notifications
    # to be sent. If the exception is a StandardError, exit_status will be 2.
    # If the exception is not a StandardError, exit_status will be 3.
    #
    # If any exception is raised, any defined +after+ hook will be skipped.
    def before(&block)
      @before = block if block
      @before
    end

    ##
    # Defines a block of code to run after the model's procedures.
    #
    # This code is ensured to run, even if the model failed, **unless** a
    # +before+ hook raised an exception and aborted the model.
    #
    # The code block will be passed the model's current exit_status:
    #
    # `0`: Success, no warnings.
    # `1`: Success, but warnings were logged.
    # `2`: Failure, but additional models/triggers will still be processed.
    # `3`: Failure, no additional models/triggers will be processed.
    #
    # The model's exit_status may be elevated based on the after hook's
    # actions, but will never be decreased.
    #
    # Warnings logged within the after hook may elevate the model's
    # exit_status to 1 and cause warning notifications to be sent.
    #
    # Raising an exception may elevate the model's exit_status and cause
    # failure notifications to be sent. If the exception is a StandardError,
    # the exit_status will be elevated to 2. If the exception is not a
    # StandardError, the exit_status will be elevated to 3.
    def after(&block)
      @after = block if block
      @after
    end

    ##
    # Performs the backup process
    #
    # Once complete, #exit_status will indicate the result of this process.
    #
    # If any errors occur during the backup process, all temporary files will
    # be left in place. If the error occurs before Packaging, then the
    # temporary folder (tmp_path/trigger) will remain and may contain all or
    # some of the configured Archives and/or Database dumps. If the error
    # occurs after Packaging, but before the Storages complete, then the final
    # packaged files (located in the root of tmp_path) will remain.
    #
    # *** Important ***
    # If an error occurs and any of the above mentioned temporary files remain,
    # those files *** will be removed *** before the next scheduled backup for
    # the same trigger.
    def perform!
      @started_at = Time.now.utc
      @time = package.time = started_at.strftime("%Y.%m.%d.%H.%M.%S")

      log!(:started)
      before_hook

      procedures.each do |procedure|
        procedure.is_a?(Proc) ? procedure.call : procedure.each(&:perform!)
      end

      syncers.each(&:perform!)

    rescue Interrupt
      @interrupted = true
      raise

    rescue Exception => err
      @exception = err

    ensure
      unless @interrupted
        set_exit_status
        @finished_at = Time.now.utc
        log!(:finished)
        after_hook
      end
    end

    ##
    # The duration of the backup process (in format: HH:MM:SS)
    def duration
      return unless finished_at
      elapsed_time(started_at, finished_at)
    end

    private

    ##
    # Returns an array of procedures that will be performed if any
    # Archives or Databases are configured for the model.
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

    ##
    # Sets or updates the model's #exit_status.
    def set_exit_status
      @exit_status = if exception
        exception.is_a?(StandardError) ? 2 : 3
      else
        Logger.has_warnings? ? 1 : 0
      end
    end

    ##
    # Runs the +before+ hook.
    # Any exception raised will be wrapped and re-raised, where it will be
    # handled by #perform the same as an exception raised while performing
    # the model's #procedures. Only difference is that an exception raised
    # here will prevent any +after+ hook from being run.
    def before_hook
      return unless before

      Logger.info 'Before Hook Starting...'
      before.call
      Logger.info 'Before Hook Finished.'

    rescue Exception => err
      @before_hook_failed = true
      ex = err.is_a?(StandardError) ? Error : FatalError
      raise ex.wrap(err, 'Before Hook Failed!')
    end

    ##
    # Runs the +after+ hook.
    # Any exception raised here will be logged only and the model's
    # #exit_status will be elevated if neccessary.
    def after_hook
      return unless after && !@before_hook_failed

      Logger.info 'After Hook Starting...'
      after.call(exit_status)
      Logger.info 'After Hook Finished.'

      set_exit_status # in case hook logged warnings

    rescue Exception => err
      fatal = !err.is_a?(StandardError)
      ex = fatal ? FatalError : Error
      Logger.error ex.wrap(err, 'After Hook Failed!')
      # upgrade exit_status if needed
      (@exit_status = fatal ? 3 : 2) unless exit_status == 3
    end

    ##
    # Logs messages when the model starts and finishes.
    #
    # #exception will be set here if #exit_status is > 1,
    # since log(:finished) is called before the +after+ hook.
    def log!(action)
      case action
      when :started
        Logger.info "Performing Backup for '#{ label } (#{ trigger })'!\n" +
            "[ backup #{ VERSION } : #{ RUBY_DESCRIPTION } ]"

      when :finished
        if exit_status > 1
          ex = exit_status == 2 ? Error : FatalError
          err = ex.wrap(exception, "Backup for #{ label } (#{ trigger }) Failed!")
          Logger.error err
          Logger.error "\nBacktrace:\n\s\s" + err.backtrace.join("\n\s\s") + "\n\n"

          Cleaner.warnings(self)
        else
          msg = "Backup for '#{ label } (#{ trigger })' "
          if exit_status == 1
            msg << "Completed Successfully (with Warnings) in #{ duration }"
            Logger.warn msg
          else
            msg << "Completed Successfully in #{ duration }"
            Logger.info msg
          end
        end
      end
    end

    ##
    # Returns a string representing the elapsed time in HH:MM:SS.
    def elapsed_time(start_time, finish_time)
      duration  = finish_time.to_i - start_time.to_i
      hours     = duration / 3600
      remainder = duration - (hours * 3600)
      minutes   = remainder / 60
      seconds   = remainder - (minutes * 60)
      '%02d:%02d:%02d' % [hours, minutes, seconds]
    end

  end
end
