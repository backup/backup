# encoding: utf-8

module Backup
  class Finder
    attr_accessor :trigger, :config
    
    ##
    # The wildcard character to match triggers
    # Can be used alone or in mask (e.g. web_* )
    WILDCARD = '*' 

    ##
    # Initializes a new Backup::Finder object
    # and stores the path to the configuration file
    def initialize(trigger, config = CONFIG_FILE)
      @trigger = trigger.to_sym
      @config  = config
    end

    ##
    # Tries to find and return the proper
    # backup model configuration (specified by the 'trigger')
    def find
      load_config!

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
    
    ##
    # Tries to find and return the all triggers
    # matching wildcard (specified by the 'trigger')
    def matching
      ##
      # Define the TIME constants unless defined
      ::Backup.send(:const_set, :TIME, Time.now.strftime("%Y.%m.%d.%H.%M.%S")) unless defined? Backup::TIME
      
      ##
      # Parses the backup configuration file
      load_config!
      
      triggers = Backup::Model.all.map{|model| model.trigger.to_s }
      
      ##
      # Removes the TIME constant
      ::Backup.send(:remove_const, :TIME) if defined? Backup::TIME
      
      ##
      # Make regexp replacing wildcard character by (.+)
      wildcard = %r{^#{trigger.to_s.gsub(WILDCARD, '(.+)')}$}
      
      ##
      # Returns all trigger names matching wildcard
      triggers.select { |trigger| trigger =~ wildcard }
    end
    
    private
    
    ##
    # Tries to find and load the configuration file
    def load_config!
      unless File.exist?(config)
        puts "Could not find a configuration file in '#{config}'."; exit
      end

      ##
      # Loads the backup configuration file
      instance_eval(File.read(config))
    end
  end
end
