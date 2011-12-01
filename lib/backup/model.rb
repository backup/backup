# encoding: utf-8

module Backup
  class Model
    include Backup::CLI::Helpers

    ##
    # The trigger is used as an identifier for
    # initializing the backup process
    attr_accessor :trigger

    ##
    # The label is used for a more friendly user output
    attr_accessor :label

    ##
    # The databases attribute holds an array of database objects
    attr_accessor :databases

    ##
    # The archives attr_accessor holds an array of archive objects
    attr_accessor :archives

    ##
    # The encryptors attr_accessor holds an array of encryptor objects
    attr_accessor :encryptors

    ##
    # The compressors attr_accessor holds an array of compressor objects
    attr_accessor :compressors

    ##
    # The notifiers attr_accessor holds an array of notifier objects
    attr_accessor :notifiers

    ##
    # The storages attribute holds an array of storage objects
    attr_accessor :storages

    ##
    # The syncers attribute holds an array of syncer objects
    attr_accessor :syncers

    ##
    # The chunk_size attribute holds the size of the chunks in megabytes
    attr_accessor :chunk_size

    ##
    # The time when the backup initiated (in format: 2011.02.20.03.29.59)
    attr_accessor :time

    class << self
      ##
      # The Backup::Model.all class method keeps track of all the models
      # that have been instantiated. It returns the @all class variable,
      # which contains an array of all the models
      attr_accessor :all

      ##
      # Contains the current file extension (this changes from time to time after a file
      # gets compressed or encrypted so we can keep track of the correct file when new
      # extensions get appended to the current file name)
      attr_accessor :extension

      ##
      # Contains the currently-in-use model. This attribute should get set by Backup::Finder.
      # Use Backup::Model.current to retrieve the actual data of the model
      attr_accessor :current

      ##
      # Contains an array of chunk suffixes for a given file
      attr_accessor :chunk_suffixes

      ##
      # Returns the full path to the current file (including the current extension).
      # To just return the filename and extension without the path, use File.basename(Backup::Model.file)
      def file
        File.join(TMP_PATH, "#{ TIME }.#{ TRIGGER }.#{ Backup::Model.extension }")
      end

      ##
      # Returns the @chunk_suffixes variable, sets it to an emtpy array if nil
      def chunk_suffixes
        @chunk_suffixes ||= Array.new
      end

      ##
      # Returns the temporary trigger path of the current model
      # e.g. /Users/Michael/tmp/backup/my_trigger
      def tmp_path
        File.join(TMP_PATH, TRIGGER)
      end
    end

    ##
    # Accessible through "Backup::Model.all", it stores an array of Backup::Model instances.
    # Everytime a new Backup::Model gets instantiated it gets pushed into this array
    @all = Array.new

    ##
    # Contains the current file extension (should change after each compression or encryption)
    @extension = 'tar'

    ##
    # Takes a trigger, label and the configuration block and instantiates the model.
    # The TIME (time of execution) gets stored in the @time attribute.
    # After the instance has evaluated the configuration block and properly set the
    # configuration for the model, it will append the newly created "model" instance
    # to the @all class variable (Array) so it can be accessed by Backup::Finder
    # and any other location
    def initialize(trigger, label, &block)
      @trigger     = trigger
      @label       = label
      @time        = TIME

      procedure_instance_variables.each do |variable|
        instance_variable_set(variable, Array.new)
      end

      instance_eval(&block)
      Backup::Model.all << self
    end

    ##
    # Adds a database to the array of databases
    # to dump during the backup process
    def database(database, &block)
      @databases << Backup::Database.const_get(
        last_constant(database)
      ).new(&block)
    end

    ##
    # Adds an archive to the array of archives
    # to store during the backup process
    def archive(name, &block)
      @archives << Backup::Archive.new(name, &block)
    end

    ##
    # Adds an encryptor to the array of encryptors
    # to use during the backup process
    def encrypt_with(name, &block)
      @encryptors << Backup::Encryptor.const_get(
        last_constant(name)
      ).new(&block)
    end

    ##
    # Adds a compressor to the array of compressors
    # to use during the backup process
    def compress_with(name, &block)
      @compressors << Backup::Compressor.const_get(
        last_constant(name)
      ).new(&block)
    end

    ##
    # Adds a notifier to the array of notifiers
    # to use during the backup process
    def notify_by(name, &block)
      @notifiers << Backup::Notifier.const_get(
        last_constant(name)
      ).new(&block)
    end

    ##
    # Adds a storage method to the array of storage
    # methods to use during the backup process
    def store_with(storage, &block)
      @storages << Backup::Storage.const_get(
        last_constant(storage)
      ).new(&block)
    end

    ##
    # Adds a syncer method to the array of syncer
    # methods to use during the backup process
    def sync_with(syncer, &block)
      @syncers << Backup::Syncer.const_get(
        last_constant(syncer)
      ).new(&block)
    end

    ##
    # Adds a method that allows the user to set the @chunk_size.
    # The chunk_size (in megabytes) will later determine in how many chunks the
    # backup needs to be split
    def split_into_chunks_of(chunk_size = nil)
      @chunk_size = chunk_size
    end

    ##
    # Returns the path to the current file (including proper extension)
    def file
      Backup::Model.file
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
    # Optionally encrypts the packaged file with one or more encryptors
    ##
    # [Compression]
    # Optionally compresses the packaged file with one or more compressors
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
    # After the whole backup process finishes, it'll go ahead and remove any temporary
    # file that it produced. If an exception(error) is raised during this process which
    # breaks the process, it'll always ensure it removes the temporary files regardless
    # to avoid mass consumption of storage space on the machine
    def perform!
      if databases.any? or archives.any?
        procedures.each do |procedure|
          (procedure.call; next) if procedure.is_a?(Proc)
          procedure.each(&:perform!)
        end
      end

      syncers.each(&:perform!)
      notifiers.each { |n| n.perform!(self) }
    rescue => exception
      clean!
      notifiers.each { |n| n.perform!(self, exception) }
      display_exception(exception)
      exit(1)
    end

  private

    ##
    # After all the databases and archives have been dumped and sorted,
    # these files will be bundled in to a .tar archive (uncompressed) so it
    # becomes a single (transferrable) packaged file.
    def package!
      Backup::Packager.new(self).package!
    end

    ##
    # Create a new instance of Backup::Splitter,
    # passing it the current model instance and runs it.
    def split!
      Backup::Splitter.new(self).split!
    end

    ##
    # Cleans up the temporary files that were created after the backup process finishes
    def clean!
      Backup::Cleaner.new(self).clean!
    end

    ##
    # Returns an array of procedures
    def procedures
      Array.new([
        databases, archives, lambda { package! }, compressors,
        encryptors, lambda { split! }, storages, lambda { clean! }
      ])
    end

    ##
    # Returns an Array of the names (String) of the procedure instance variables
    def procedure_instance_variables
      [:@databases, :@archives, :@encryptors, :@compressors, :@storages, :@notifiers, :@syncers]
    end

    ##
    # Returns the string representation of the last value of a nested constant
    # example: last_constant(Backup::Model::MySQL) becomes and returns "MySQL"
    def last_constant(constant)
      constant.to_s.split("::").last
    end

    ##
    # Formats an exception
    def display_exception(exception)
      Backup::Template.new({:exception => exception}).render("exception/screen.erb")
    end

  end
end
