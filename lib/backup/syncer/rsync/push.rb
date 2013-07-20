# encoding: utf-8

module Backup
  module Syncer
    module RSync
      class Push < Base

        ##
        # Mode of operation
        #
        # [:ssh (default)]
        #   Connects to the remote via SSH.
        #   Does not use an rsync daemon on the remote.
        #
        # [:ssh_daemon]
        #   Connects to the remote via SSH.
        #   Spawns a single-use daemon on the remote, which allows certain
        #   daemon features (like modules) to be used.
        #
        # [:rsync_daemon]
        #   Connects directly to an rsync daemon via TCP.
        #   Data transferred is not encrypted.
        #
        attr_accessor :mode

        ##
        # Server Address
        attr_accessor :host

        ##
        # SSH or RSync port
        #
        # For `:ssh` or `:ssh_daemon` mode, this specifies the SSH port to use
        # and defaults to 22.
        #
        # For `:rsync_daemon` mode, this specifies the TCP port to use
        # and defaults to 873.
        attr_accessor :port

        ##
        # SSH User
        #
        # If the user running the backup is not the same user that needs to
        # authenticate with the remote server, specify the user here.
        #
        # The user must have SSH keys setup for passphrase-less access to the
        # remote. If the SSH User does not have passphrase-less keys, or no
        # default keys in their `~/.ssh` directory, you will need to use the
        # `-i` option in `:additional_ssh_options` to specify the
        # passphrase-less key to use.
        #
        # Used only for `:ssh` and `:ssh_daemon` modes.
        attr_accessor :ssh_user

        ##
        # Additional SSH Options
        #
        # Used to supply a String or Array of options to be passed to the SSH
        # command in `:ssh` and `:ssh_daemon` modes.
        #
        # For example, if you need to supply a specific SSH key for the `ssh_user`,
        # you would set this to: "-i '/path/to/id_rsa'". Which would produce:
        #
        #   rsync -e "ssh -p 22 -i '/path/to/id_rsa'"
        #
        # Arguments may be single-quoted, but should not contain any double-quotes.
        #
        # Used only for `:ssh` and `:ssh_daemon` modes.
        attr_accessor :additional_ssh_options

        ##
        # RSync User
        #
        # If the user running the backup is not the same user that needs to
        # authenticate with the rsync daemon, specify the user here.
        #
        # Used only for `:ssh_daemon` and `:rsync_daemon` modes.
        attr_accessor :rsync_user

        ##
        # RSync Password
        #
        # If specified, Backup will write the password to a temporary file and
        # use it with rsync's `--password-file` option for daemon authentication.
        #
        # Note that setting this will override `rsync_password_file`.
        #
        # Used only for `:ssh_daemon` and `:rsync_daemon` modes.
        attr_accessor :rsync_password

        ##
        # RSync Password File
        #
        # If specified, this path will be passed to rsync's `--password-file`
        # option for daemon authentication.
        #
        # Used only for `:ssh_daemon` and `:rsync_daemon` modes.
        attr_accessor :rsync_password_file

        ##
        # Flag for compressing (only compresses for the transfer)
        attr_accessor :compress

        def initialize(syncer_id = nil)
          super

          @mode ||= :ssh
          @port ||= mode == :rsync_daemon ? 873 : 22
          @compress ||= false
        end

        def perform!
          log!(:started)
          write_password_file!

          create_dest_path!
          run("#{ rsync_command } #{ paths_to_push } " +
              "#{ host_options }'#{ dest_path }'")

          log!(:finished)
        ensure
          remove_password_file!
        end

        private

        ##
        # Remove any preceeding '~/', since this is on the remote,
        # and remove any trailing `/`.
        def dest_path
          @dest_path ||= path.sub(/^~\//, '').sub(/\/$/, '')
        end

        ##
        # Runs a 'mkdir -p' command on the remote to ensure the dest_path exists.
        # This used because rsync will attempt to create the path, but will only
        # call 'mkdir' without the '-p' option. This is only applicable in :ssh
        # mode, and only used if the path would require this.
        def create_dest_path!
          return unless mode == :ssh && dest_path.index('/').to_i > 0

          run "#{ utility(:ssh) } #{ ssh_transport_args } #{ host } " +
                 %Q["mkdir -p '#{ dest_path }'"]
        end

        ##
        # For Push, this will prepend the #dest_path.
        # For Pull, this will prepend the first path in #paths_to_pull.
        def host_options
          if mode == :ssh
            "#{ host }:"
          else
            user = "#{ rsync_user }@" if rsync_user
            "#{ user }#{ host }::"
          end
        end

        ##
        # Common base command, plus options for Push/Pull
        def rsync_command
          super << compress_option << password_option << transport_options
        end

        def compress_option
          compress ? ' --compress' : ''
        end

        def password_option
          return '' if mode == :ssh

          path = @password_file ? @password_file.path : rsync_password_file
          path ? " --password-file='#{ File.expand_path(path) }'" : ''
        end

        def transport_options
          if mode == :rsync_daemon
            " --port #{ port }"
          else
            %Q[ -e "#{ utility(:ssh) } #{ ssh_transport_args }"]
          end
        end

        def ssh_transport_args
          args = "-p #{ port } "
          args << "-l #{ ssh_user } " if ssh_user
          args << Array(additional_ssh_options).join(' ')
          args.rstrip
        end

        def write_password_file!
          return unless rsync_password && mode != :ssh

          @password_file = Tempfile.new('backup-rsync-password')
          @password_file.write(rsync_password)
          @password_file.close
        end

        def remove_password_file!
          @password_file.delete if @password_file
        end

        attr_deprecate :additional_options, :version => '3.2.0',
                       :message => 'Use #additional_rsync_options instead.',
                       :action => lambda {|klass, val|
                         klass.additional_rsync_options = val
                       }

        attr_deprecate :username, :version => '3.2.0',
                       :message => 'Use #ssh_user instead.',
                       :action => lambda {|klass, val|
                         klass.ssh_user = val
                       }
        attr_deprecate :password, :version => '3.2.0',
                       :message => 'Use #rsync_password instead.',
                       :action => lambda {|klass, val|
                         klass.rsync_password = val
                       }
        attr_deprecate :ip, :version => '3.2.0',
                       :message => 'Use #host instead.',
                       :action => lambda {|klass, val|
                         klass.host = val
                       }
      end
    end
  end
end
