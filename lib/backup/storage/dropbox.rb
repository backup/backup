require 'backup/connection/dropbox'

module Backup
  module Storage
    class Dropbox < Base
      def initialize(adapter)
        dropbox = Backup::Connection::Dropbox.new(adapter)
        dropbox.store
      end
    end
  end
end
