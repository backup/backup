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
    # The adapters holds an array of adapter objects
    attr_accessor :adapters

    ##
    # The storages attribute holds an array of storage objects
    attr_accessor :storages

    ##
    # Takes a trigger, label and the intructions block
    def initialize(trigger, label = false, &block)
      @trigger  = trigger
      @label    = label
      @adapters = Array.new
      @storages = Array.new

      instance_eval(&block)
    end

    ##
    # Adds an adapter to the array of adapters to use
    # during the backup process
    def use_adapter(adapter, &block)
      @adapters << Backup::Adapters.const_get(adapter).new(&block)
    end

    ##
    # Adds a storage method to the array of storage methods to use
    # during the backup process
    def store_to(storage, &block)
      @storages << Backup::Storage.const_get(storage).new(&block)
    end

  end
end
