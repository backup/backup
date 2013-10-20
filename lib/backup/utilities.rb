# encoding: utf-8

module Backup
  module Utilities
    class Error < Backup::Error; end

    UTILITY = {}
    NAMES = %w{
      tar cat split sudo chown hostname
      gzip bzip2 lzma pbzip2
      mongo mongodump mysqldump pg_dump pg_dumpall redis-cli riak-admin
      gpg openssl
      rsync ssh
      sendmail exim
      send_nsca
    }

    module DSL
      class << self
        ##
        # Allow users to set the path for all utilities in the .configure block.
        #
        # Utility names with dashes ('redis-cli') will be set using method calls
        # with an underscore ('redis_cli').
        NAMES.each do |name|
          define_method name.gsub('-', '_'), lambda {|val|
            path = File.expand_path(val)
            unless File.executable?(path)
              raise Utilities::Error, <<-EOS
                The path given for '#{ name }' was not found or not executable.
                Path was: #{ path }
              EOS
            end
            UTILITY[name] = path
          }
        end

        ##
        # Allow users to set the +tar+ distribution if needed. (:gnu or :bsd)
        def tar_dist(val)
          Utilities.tar_dist(val)
        end
      end
    end

    class << self
      ##
      # Configure the path to system utilities used by Backup.
      #
      # Backup will attempt to locate any required system utilities using a
      # +which+ command call. If a utility can not be found, or you need to
      # specify an alternate path for a utility, you may do so in your
      # +config.rb+ file using this method.
      #
      # Backup supports both GNU and BSD utilities.
      # While Backup uses these utilities in a manner compatible with either
      # version, the +tar+ utility requires some special handling with respect
      # to +Archive+s. Backup will attempt to detect if the +tar+ command
      # found (or set here) is GNU or BSD. If for some reason this fails,
      # this may be set using the +tar_dist+ command shown below.
      #
      #   Backup::Utilities.configure do
      #     # General Utilites
      #     tar      '/path/to/tar'
      #     tar_dist :gnu   # or :bsd
      #     cat      '/path/to/cat'
      #     split    '/path/to/split'
      #     sudo     '/path/to/sudo'
      #     chown    '/path/to/chown'
      #     hostname '/path/to/hostname'
      #
      #     # Compressors
      #     gzip    '/path/to/gzip'
      #     bzip2   '/path/to/bzip2'
      #     lzma    '/path/to/lzma'   # deprecated. use a Custom Compressor
      #     pbzip2  '/path/to/pbzip2' # deprecated. use a Custom Compressor
      #
      #     # Database Utilities
      #     mongo       '/path/to/mongo'
      #     mongodump   '/path/to/mongodump'
      #     mysqldump   '/path/to/mysqldump'
      #     pg_dump     '/path/to/pg_dump'
      #     pg_dumpall  '/path/to/pg_dumpall'
      #     redis_cli   '/path/to/redis-cli'
      #     riak_admin  '/path/to/riak-admin'
      #
      #     # Encryptors
      #     gpg     '/path/to/gpg'
      #     openssl '/path/to/openssl'
      #
      #     # Syncer and Storage
      #     rsync   '/path/to/rsync'
      #     ssh     '/path/to/ssh'
      #
      #     # Notifiers
      #     sendmail  '/path/to/sendmail'
      #     exim      '/path/to/exim'
      #     send_nsca '/path/to/send_nsca'
      #   end
      #
      # These paths may be set using absolute paths, or relative to the
      # working directory when Backup is run.
      #
      # Note that many of Backup's components currently have their own
      # configuration settings for utility paths. For instance, when configuring
      # a +MySQL+ database backup, +mysqldump_utility+ may be used:
      #
      #   database MySQL do |db|
      #     db.mysqldump_utility = '/path/to/mysqldump'
      #   end
      #
      # Use of these configuration settings will override the path set here.
      # (The use of these may be deprecated in the future)
      def configure(&block)
        DSL.instance_eval(&block)
      end

      def tar_dist(val)
        # the acceptance tests need to be able to reset this to nil
        @gnu_tar = val.nil? ? nil : val == :gnu
      end

      def gnu_tar?
        return @gnu_tar unless @gnu_tar.nil?
        @gnu_tar = !!run("#{ utility(:tar) } --version").match(/GNU/)
      end

      private

      ##
      # Returns the full path to the specified utility.
      # Raises an error if utility can not be found in the system's $PATH
      def utility(name)
        name = name.to_s.strip
        raise Error, 'Utility Name Empty' if name.empty?

        UTILITY[name] ||= %x[which '#{ name }' 2>/dev/null].chomp
        raise Error, <<-EOS if UTILITY[name].empty?
          Could not locate '#{ name }'.
          Make sure the specified utility is installed
          and available in your system's $PATH, or specify it's location
          in your 'config.rb' file using Backup::Utilities.configure
        EOS

        UTILITY[name].dup
      end

      ##
      # Returns the name of the command name from the given command line.
      # This is only used to simplify log messages.
      def command_name(command)
        parts = []
        command = command.split(' ')
        command.shift while command[0].to_s.include?('=')
        parts << command.shift.split('/')[-1]
        if parts[0] == 'sudo'
          until command.empty?
            part = command.shift
            if part.include?('/')
              parts << part.split('/')[-1]
              break
            else
              parts << part
            end
          end
        end
        parts.join(' ')
      end

      ##
      # Runs a system command
      #
      # All messages generated by the command will be logged.
      # Messages on STDERR will be logged as warnings.
      #
      # If the command fails to execute, or returns a non-zero exit status
      # an Error will be raised.
      #
      # Returns STDOUT
      def run(command)
        name = command_name(command)
        Logger.info "Running system utility '#{ name }'..."

        begin
          out, err = '', ''
          # popen4 doesn't work in 1.8.7 with stock versions of ruby shipped
          # with major OSs. Hack to make it stop segfaulting.
          # See: https://github.com/engineyard/engineyard/issues/115
          GC.disable if RUBY_VERSION < '1.9'
          ps = Open4.popen4(command) do |pid, stdin, stdout, stderr|
            stdin.close
            out, err = stdout.read.strip, stderr.read.strip
          end
        rescue Exception => e
          raise Error.wrap(e, "Failed to execute '#{ name }'")
        ensure
          GC.enable if RUBY_VERSION < '1.9'
        end

        if ps.success?
          unless out.empty?
            Logger.info(
              out.lines.map {|line| "#{ name }:STDOUT: #{ line }" }.join
            )
          end

          unless err.empty?
            Logger.warn(
              err.lines.map {|line| "#{ name }:STDERR: #{ line }" }.join
            )
          end

          return out
        else
          raise Error, <<-EOS
            '#{ name }' failed with exit status: #{ ps.exitstatus }
            STDOUT Messages: #{ out.empty? ? 'None' : "\n#{ out }" }
            STDERR Messages: #{ err.empty? ? 'None' : "\n#{ err }" }
          EOS
        end
      end

      def reset!
        UTILITY.clear
        @gnu_tar = nil
      end
    end

    # Allows these utility methods to be included in other classes,
    # while allowing them to be stubbed in spec_helper for all specs.
    module Helpers
      [:utility, :command_name, :run].each do |name|
        define_method name, lambda {|arg| Utilities.send(name, arg) }
        private name
      end
      private
      def gnu_tar?; Utilities.gnu_tar?; end
    end
  end
end
