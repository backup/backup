# encoding: utf-8

module Backup
  module Storage
    class RSync < Base
      include Backup::Utilities::Helpers

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
      #
      # If not specified, the storage operation will be local.
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
      # Additional String or Array of options for the rsync cli
      attr_accessor :additional_rsync_options

      ##
      # Flag for compressing (only compresses for the transfer)
      attr_accessor :compress

      ##
      # Path to store the synced backup package file(s) to.
      #
      # If no +host+ is specified, then +path+ will be local, and the only
      # other used option would be +additional_rsync_options+.
      # +path+ will be expanded, so '~/my_path' will expand to '$HOME/my_path'.
      #
      # If a +host+ is specified, this will be a path on the host.
      # If +mode+ is `:ssh` (default), then any relative path, or path starting
      # with '~/' will be relative to the directory the ssh_user is logged
      # into. For `:ssh_daemon` or `:rsync_daemon` modes, this would reference
      # an rsync module/path.
      #
      # In :ssh_daemon and :rsync_daemon modes, the files will be stored
      # directly to the +path+ given. The path (or path defined by your rsync
      # module) must already exist.
      # Note that no additional `<trigger>` directory will be added to this path.
      #
      # In :ssh mode or local operation (no +host+ specified), the actual
      # destination path will be `<path>/<trigger>/`. This path will be created
      # if needed - either locally, or on the remote for :ssh mode.
      # This behavior will change in v4.0, when :ssh mode and local operations
      # will also store the files directly in the +path+ given.
      attr_accessor :path

      def initialize(model, storage_id = nil)
        super

        @mode ||= :ssh
        @port ||= mode == :rsync_daemon ? 873 : 22
        @compress ||= false
        @path ||= '~/backups'
      end

      private

      def transfer!
        write_password_file
        create_remote_path

        package.filenames.each do |filename|
          src = "'#{ File.join(Config.tmp_path, filename) }'"
          dest = "#{ host_options }'#{ File.join(remote_path, filename) }'"
          Logger.info "Syncing to #{ dest }..."
          run("#{ rsync_command } #{ src } #{ dest }")
        end
      ensure
        remove_password_file
      end

      # Storage::RSync doesn't cycle
      def cycle!; end

      ##
      # Other storages add an additional timestamp directory to this path.
      # This is not desired here, since we need to transfer the package files
      # to the same location each time.
      #
      # Note: In v4.0, the additional trigger directory will to be dropped
      # from remote_path for both local and :ssh mode, so the package files
      # will be stored directly in #path.
      def remote_path
        @remote_path ||= begin
          if host
            if mode == :ssh
              File.join(path.sub(/^~\//, ''), package.trigger)
            else
              path.sub(/^~\//, '').sub(/\/$/, '')
            end
          else
            File.join(File.expand_path(path), package.trigger)
          end
        end
      end

      ##
      # Runs a 'mkdir -p' command on the host (or locally) to ensure the
      # dest_path exists. This is used because we're transferring a single
      # file, and rsync won't attempt to create the intermediate directories.
      #
      # This is only applicable locally and in :ssh mode.
      # In :ssh_daemon and :rsync_daemon modes the `path` would include a
      # module name that must define a path on the remote that already exists.
      def create_remote_path
        if host
          run("#{ utility(:ssh) } #{ ssh_transport_args } #{ host } " +
                  %Q["mkdir -p '#{ remote_path }'"]) if mode == :ssh
        else
          FileUtils.mkdir_p(remote_path)
        end
      end

      def host_options
        @host_options ||= begin
          if !host
            ''
          elsif mode == :ssh
            "#{ host }:"
          else
            user = "#{ rsync_user }@" if rsync_user
            "#{ user }#{ host }::"
          end
        end
      end

      def rsync_command
        @rsync_command ||= begin
          cmd = utility(:rsync) << ' --archive' <<
              " #{ Array(additional_rsync_options).join(' ') }".rstrip
          cmd << compress_option << password_option << transport_options if host
          cmd
        end
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

      def write_password_file
        return unless host && rsync_password && mode != :ssh

        @password_file = Tempfile.new('backup-rsync-password')
        @password_file.write(rsync_password)
        @password_file.close
      end

      def remove_password_file
        @password_file.delete if @password_file
      end

      attr_deprecate :local, :version => '3.2.0',
                     :message => "If 'host' is not set, the operation will be local."

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
