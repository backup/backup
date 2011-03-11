# encoding: utf-8

module Backup

  ##
  # Usage:
  #
  #  # Returns the current backup version based on the defined constants
  #    Backup::Version.current
  #
  #  # Returns a gemspec compatible version number based on the defined constants
  #    Backup::Version.gemspec
  #
  class Version

    ##
    # MAJOR:
    #  Defines the major version
    # MINOR:
    #  Defines the minor version
    # PATCH:
    #  Defines the patch version
    # BUILD:
    #  Defines the build version ( use 'false' if no build )
    MAJOR, MINOR, PATCH, BUILD = 3, 0, 2, 0

    # ========================================================= #
    #  ADJUST THE CONSTANTS ABOVE TO CHANGE THE BACKUP VERSION  #
    # ========================================================= #

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
    # Returns the patch version ( updates, features and (crucial) bug fixes based off of multiple builds )
    def self.patch
      PATCH
    end

    ##
    # Returns the build version ( improvements, small additions, frequent releases )
    def self.build
      BUILD
    end

    ##
    # Returns the current version ( not for gemspec / rubygems )
    def self.current
      "#{major}.#{minor}.#{patch} / build #{build or 0}"
    end

    ##
    # Returns the (gemspec qualified) current version
    def self.gemspec
      if build.eql?(false)
        "#{major}.#{minor}.#{patch}"
      else
        "#{major}.#{minor}.#{patch}.build.#{build}"
      end
    end

  end
end
