# encoding: utf-8

##
# Require the tempfile Ruby library when Backup::Syncer::RSync is loaded
require 'tempfile'

module Backup
  module Syncer
    class InverseRSync < RSync
      ##
      # Directories to sync
      attr_accessor :remote_path
      
      ##
      # Performs the RSync operation
      # debug options: -vhP
      # recursively (-r option)
      def perform!
        Logger.message("#{ self.class } started syncing #{ remote_path }.")
        Logger.silent(run("mkdir -p #{ path }"))
        Logger.silent(
          run("#{ utility(:rsync) } -vhPr #{ options } '#{ username }@#{ ip }:#{ remote_path }' '#{ path }'")
        )

        remove_password_file!
      end
    end
  end
end
