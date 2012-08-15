# encoding: utf-8

module Backup
  module Syncer
    module RSync
      class Push < Base

        ##
        # Server credentials
        attr_accessor :username, :password

        ##
        # Server IP Address and SSH port
        attr_accessor :ip

        ##
        # The SSH port to connect to
        attr_accessor :port

        ##
        # Flag for compressing (only compresses for the transfer)
        attr_accessor :compress

        ##
        # Flag for accessing rsync daemon (instead of SSH access)
        attr_accessor :daemon

        ##
        # Instantiates a new RSync::Push or RSync::Pull Syncer.
        #
        # Pre-configured defaults specified in
        # Configuration::Syncer::RSync::Push or
        # Configuration::Syncer::RSync::Pull
        # are set via a super() call to RSync::Base,
        # which in turn will invoke Syncer::Base.
        #
        # Once pre-configured defaults and RSync specific defaults are set,
        # the block from the user's configuration file is evaluated.
        def initialize(&block)
          super

          @port               ||= 22
          @compress           ||= false
          @daemon             ||= false

          instance_eval(&block) if block_given?
        end

        ##
        # Performs the RSync:Push operation
        # debug options: -vhP
        def perform!
          write_password_file!

          Logger.message(
            "#{ syncer_name } started syncing the following directories:\n\s\s" +
            @directories.join("\n\s\s")
          )
          run("#{ utility(:rsync) } #{ options } #{ directories_option } " +
              "'#{ username }@#{ ip }#{rsync_path_separator}#{ dest_path }'")

        ensure
          remove_password_file!
        end

        private

        ##
        # Return @path with any preceeding "~/" removed
        def dest_path
          @dest_path ||= @path.sub(/^\~\//, '')
        end

        ##
        # Returns all the specified Rsync::[Push/Pull] options,
        # concatenated, ready for the CLI
        def options
          ([archive_option, mirror_option, compress_option, port_option,
            password_option] + additional_options).compact.join("\s")
        end

        ##
        # Returns Rsync syntax for compressing the file transfers
        def compress_option
          '--compress' if @compress
        end

        ##
        # Returns Rsync syntax for defining a port to connect to (or nothing, if connect to daemon)
        def port_option
          "-e 'ssh -p #{@port}'" unless @daemon
        end

        ##
        # Returns Rsync syntax for setting a password (via a file)
        def password_option
          "--password-file='#{@password_file.path}'" if @password_file
        end

        ##
        # Writes the provided password to a temporary file so that
        # the rsync utility can read the password from this file
        def write_password_file!
          unless @password.nil?
            @password_file = Tempfile.new('backup-rsync-password')
            @password_file.write(@password)
            @password_file.close
          end
        end

        ##
        # Removes the previously created @password_file
        # (temporary file containing the password)
        def remove_password_file!
          @password_file.delete if @password_file
          @password_file = nil
        end

        def rsync_path_separator
          @daemon ? "::" : ":"
        end
      end
    end
  end
end
