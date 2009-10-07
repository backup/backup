require 'backup/base'
require 'backup/encrypt'
require 'backup/adapter/sqlite3'
require 'backup/adapter/mysql'
require 'backup/adapter/assets'
require 'backup/adapter/custom'
require 'backup/transfer/base'
require 'backup/transfer/s3'
require 'backup/transfer/ssh'
require 'backup/connection/base'
require 'backup/connection/s3'
require 'backup/connection/ssh'
require 'backup/backup_record/s3'

module Backup
end