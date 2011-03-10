# encoding: utf-8

module Backup
  class Finder
    attr_accessor :trigger, :config

    ##
    # Initializes a new Backup::Finder object
    # and stores the path to the configuration file
    def initialize(trigger, config)
      @trigger = trigger.to_sym
      @config  = config
    end

    ##
    # Tries to find and load the configuration file and return the proper
    # backup model configuration (specified by the 'trigger')
    def find
      unless File.exist?(config)
        puts "Could not find a configuration file in '#{config}'."; exit
      end

      ##
      # Loads the backup configuration file
      instance_eval(File.read(config))

      ##
      # Iterates through all the instantiated backup models and returns
      # the one that matches the specified 'trigger'
      Backup::Model.all.each do |model|
        if model.trigger.eql?(trigger)
          return Backup::Model.current = model
        end
      end

      puts "Could not find trigger '#{trigger}' in '#{config}'."; exit
    end
  end
end
