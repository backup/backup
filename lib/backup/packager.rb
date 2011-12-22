# encoding: utf-8

module Backup
  class Packager
    include Backup::CLI::Helpers

    ##
    # Holds an instance of the current Backup model
    attr_accessor :model

    ##
    # Creates a new instance of the Backup::Packager class
    def initialize(model)
      @model = model
    end

    ##
    # Packages the current state of the backup in to a single archived file.
    def package!
      Logger.message "#{ self.class } started packaging the backup files."
      run("#{ utility(:tar) } -c -f '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }' -C '#{ Backup::TMP_PATH }' '#{ Backup::TRIGGER }'")
    end

  end
end
