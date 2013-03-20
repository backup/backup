# encoding: utf-8

module BackupSpec
  class PerformedJob
    attr_reader :logger, :package
    def initialize(trigger)
      @logger = Backup::Logger.saved.shift
      @package = Package.new(trigger)
    end
  end
end
