# encoding: utf-8

module Backup
  module Syncer
    module RSync
      class Pull < Push

        ##
        # Performs the RSync::Pull operation
        # debug options: -vhP
        def perform!
          write_password_file!

          @directories.each do |directory|
            Logger.message("#{ syncer_name } started syncing '#{ directory }'.")
            run("#{ utility(:rsync) } #{ options } " +
                "'#{ username }@#{ ip }:#{ directory.sub(/^\~\//, '') }' " +
                "'#{ dest_path }'")
          end

        ensure
          remove_password_file!
        end

        private

        ##
        # Return expanded @path, since this path is local
        def dest_path
          @dest_path ||= File.expand_path(@path)
        end

      end
    end
  end
end
