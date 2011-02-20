# encoding: utf-8

module Backup
  class Model

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
    # Takes a trigger, label and the intructions block
    def initialize(trigger, label = false, &block)
      @trigger   = trigger
      @label     = label
      @databases = Array.new
      @storages  = Array.new
      @time      = TIME

      instance_eval(&block)
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
    def perform!

      ##
      # Dump all databases
      databases.each(&:perform!)

      ##
      # Store all backups to the storage locations
      storages.each(&:perform!)

    end

  end
end
