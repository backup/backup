# encoding: utf-8

module Backup
  class Logger
    class Logfile
      class Error < Backup::Error; end

      class Options
        ##
        # Enable the use of Backup's log file.
        #
        # While not necessary, as this is +true+ by default,
        # this may also be set on the command line using +--logfile+.
        #
        # The use of Backup's log file may be disabled using the
        # command line option +--no-logfile+.
        #
        # If +--no--logfile+ is used on the command line, then the
        # log file will be disabled and any setting here will be ignored.
        #
        # @param [Boolean, nil]
        # @return [Boolean, nil] Default: +true+
        attr_reader :enabled

        ##
        # Path to directory where Backup's logfile will be written.
        #
        # This may be given as an absolute path, or a path relative
        # to Backup's +--root-path+ (which defaults to +~/Backup+).
        #
        # This may also be set on the command line using +--log-path+.
        # If set on the command line, any setting here will be ignored.
        #
        # @param [String]
        # @return [String] Default: 'log'
        attr_reader :log_path

        ##
        # Backup's logfile in which backup logs can be written
        #
        # As there is already a log_path, this can simply be just a file name
        # that will be created (If not exists) on log_path directory
        #
        # This may also be set on the command line using +--log-file+.
        # If set on the command line, any setting here will be ignored.
        #
        # @param [String]
        # @return [String] Default: 'backup.log'
        attr_reader :log_file

        ##
        # Size in bytes to truncate logfile to before backup jobs are run.
        #
        # This is done once before all +triggers+, so the maximum logfile size
        # would be this value plus whatever the jobs produce.
        #
        # @param [Integer]
        # @return [Integer] Default: +500_000+
        attr_accessor :max_bytes

        def initialize
          @enabled = true
          @log_path = ''
          @max_bytes = 500_000
        end

        def enabled?
          !!enabled
        end

        def enabled=(val)
          @enabled = val unless enabled.nil?
        end

        def log_path=(val)
          @log_path = val.to_s.strip if log_path.empty?
        end
      end

      def initialize(options)
        @options = options
        @logfile = setup_logfile
        truncate!
      end

      def log(message)
        File.open(@logfile, 'a') {|f| f.puts message.formatted_lines }
      end

      private

      ##
      # Returns the full path to the log file, based on the configured
      # @options.log_path, and ensures the path to the log file exists.
      def setup_logfile
        # strip any trailing '/' in case the user supplied this as part of
        # an absolute path, so we can match it against File.expand_path()
        path = @options.log_path.chomp('/')
        if path.empty?
          path = File.join(Backup::Config.root_path, 'log')
        elsif path != File.expand_path(path)
          path = File.join(Backup::Config.root_path, path)
        end
        FileUtils.mkdir_p(path)
        log_file = @options.log_file || 'backup.log'
        path = File.join(path, log_file)
        if File.exist?(path) && !File.writable?(path)
          raise Error, "Log File at '#{ path }' is not writable"
        end
        path
      end

      ##
      # Truncates the logfile to @options.max_bytes
      def truncate!
        return unless File.exist?(@logfile)

        if File.stat(@logfile).size > @options.max_bytes
          FileUtils.cp(@logfile, @logfile + '~')
          File.open(@logfile + '~', 'r') do |io_in|
            File.open(@logfile, 'w') do |io_out|
              io_in.seek(-@options.max_bytes, IO::SEEK_END) && io_in.gets
              while line = io_in.gets
                io_out.puts line
              end
            end
          end
          FileUtils.rm_f(@logfile + '~')
        end
      end
    end
  end
end
