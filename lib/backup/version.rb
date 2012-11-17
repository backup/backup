# encoding: utf-8

module Backup
  class Version

    ##
    # Change the MAJOR, MINOR and PATCH constants below
    # to adjust the version of the Backup gem
    #
    # MAJOR:
    #  Defines the major version
    # MINOR:
    #  Defines the minor version
    # PATCH:
    #  Defines the patch version
    MAJOR, MINOR, PATCH = 3, 0, 27

    ##
    # Returns the major version ( big release based off of multiple minor releases )
    def self.major
      MAJOR
    end

    ##
    # Returns the minor version ( small release based off of multiple patches )
    def self.minor
      MINOR
    end

    ##
    # Returns the patch version ( updates, features and (crucial) bug fixes )
    def self.patch
      PATCH
    end

    ##
    # Returns the current version of the Backup gem ( qualified for the gemspec )
    def self.current
      "#{major}.#{minor}.#{patch}"
    end

  end
end
