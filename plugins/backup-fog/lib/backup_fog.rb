# frozen_string_literal: true

require_relative "backup_fog/version"

require "backup"
require_relative "backup/cloud_io/s3"
require_relative "backup/logger/fog_adapter"
require_relative "backup/notifier/ses"
require_relative "backup/storage/cloud_files"
require_relative "backup/storage/s3"
require_relative "backup/syncer/cloud/cloud_files"
require_relative "backup/syncer/cloud/s3"


module BackupFog
  class Error < StandardError; end
  # Your code goes here...
end
