# encoding: utf-8

module Backup
  class Model
    include Backup::CLI

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
    # The storages attribute holds an array of storage objects
    attr_accessor :storages

    ##
    # The time when the backup initiated (in format: 2011.02.20.03.29.59)
    attr_accessor :time

    ##
    # The Backup::Model.all class method keeps track of all the models
    # that have been instantiated. It returns the @all class variable,
    # which contains an array of all the models
    class << self
      attr_accessor :all
    end

    ##
    # Accessible through "Backup::Model.all", it stores an array of Backup::Model instances.
    # Everytime a new Backup::Model gets instantiated it gets pushed into this array
    @all = Array.new

    ##
    # Takes a trigger, label and the configuration block and instantiates the model.
    # The TIME (time of execution) gets stored in the @time attribute.
    # After the instance has evaluated the configuration block and properly set the
    # configuration for the model, it will append the newly created "model" instance
    # to the @all class variable (Array) so it can be accessed by Backup::Finder
    # and any other location
    def initialize(trigger, label, &block)
      @trigger   = trigger
      @label     = label
      @databases = Array.new
      @storages  = Array.new
      @time      = TIME

      instance_eval(&block)
      Backup::Model.all << self
    end

    ##
    # Adds a database to the array of databases to dump
    # during the backup process
    def database(database, &block)
      @databases << Backup::Database.const_get(database).new(&block)
    end

    ##
    # Adds a storage method to the array of storage methods to use
    # during the backup process
    def store_to(storage, &block)
      @storages << Backup::Storage.const_get(storage).new(&block)
    end

    ##
    # Performs the backup process
    ##
    # [Databases]
    # Runs all (if any) database objects to dump the databases
    ##
    # [Storages]
    # Runs all (if any) storage objects to store the backups to remote locations
    def perform!
      databases.each do |database|
        database.perform!
      end

      package!

      storages.each do |storage|
        storage.perform!
      end

      clean!
    end

  private

    ##
    # After all the databases and archives have been dumped and sorted,
    # these files will be bundled in to a .tar archive (uncompressed) so it
    # becomes a single (transferrable) packaged file.
    def package!
      run("#{ utility(:tar) } -c '#{ File.join(TMP_PATH, TRIGGER) }' > '#{ File.join(TMP_PATH, "#{TIME}.#{TRIGGER}.tar") }'")
    end

    ##
    # Cleans up the temporary files that were created after the backup process finishes
    def clean!
      run("#{ utility(:rm) } -rf '#{ File.join(TMP_PATH, TRIGGER) }' '#{ File.join(TMP_PATH, "#{TIME}.#{TRIGGER}.tar") }'*")
    end

  end
end
