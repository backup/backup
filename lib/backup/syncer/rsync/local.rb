# encoding: utf-8

module Backup
  module Syncer
    module RSync
      class Local < Base

        ##
        # Instantiates a new RSync::Local Syncer.
        #
        # Pre-configured defaults specified in
        # Configuration::Syncer::RSync::Local
        # are set via a super() call to RSync::Base,
        # which in turn will invoke Syncer::Base.
        #
        # Once pre-configured defaults and RSync specific defaults are set,
        # the block from the user's configuration file is evaluated.
        def initialize(&block)
          super

          instance_eval(&block) if block_given?
        end

        ##
        # Performs the RSync::Local operation
        # debug options: -vhP
        def perform!
          Logger.message(
            "#{ syncer_name } started syncing the following directories:\n\s\s" +
            @directories.join("\n\s\s")
          )
          run("#{ utility(:rsync) } #{ options } " +
              "#{ directories_option } '#{ dest_path }'")
        end

        private

        ##
        # Return expanded @path
        def dest_path
          @dest_path ||= File.expand_path(@path)
        end

        ##
        # Returns all the specified Rsync::Local options,
        # concatenated, ready for the CLI
        def options
          ([archive_option, mirror_option] +
            additional_options).compact.join("\s")
        end

      end
    end
  end
end
