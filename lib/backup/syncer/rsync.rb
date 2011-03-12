# encoding: utf-8

module Backup
  module Syncer
    class RSync
      include Backup::CLI
      include Backup::Configuration::Helpers

      ##
      # Server credentials
      attr_accessor :username, :password

      ##
      # Server IP Address and SSH port
      attr_accessor :ip

      ##
      # The SSH port to connect to
      attr_writer :port

      ##
      # Files/Folders to Sync
      attr_writer :folders

      ##
      # Path to store the synced files/folders to
      attr_accessor :path

      ##
      # Flag for mirroring the files/folders
      attr_writer :mirror

      ##
      # Flag for compressing (only compresses for the transfer)
      attr_writer :compress

      ##
      # Additional options for the rsync cli
      attr_accessor :additional_options

      ##
      # Instantiates a new RSync Syncer object and sets the default configuration
      # specified in the Backup::Configuration::Syncer::RSync. Then it sets the object
      # defaults if particular properties weren't set. Finally it'll evaluate the users
      # configuration file and overwrite anything that's been defined
      def initialize(&block)
        load_defaults!

        @folders              = Array.new
        @additional_options ||= Array.new
        @path               ||= 'backups'
        @port               ||= 22
        @mirror             ||= false
        @compress           ||= false

        instance_eval(&block) if block_given?

        @path = path.sub(/^\~\//, '')
      end

      ##
      # Performs the RSync operation
      # debug options: -vhP
      def perform!
        Logger.message("#{ self.class } started syncing #{ folders }.")
        Logger.silent( run("#{ utility(:rsync) } -vhP #{ options } #{ folders } '#{ username }@#{ ip }:#{ path }'") )
      end

      ##
      # Returns all the specified Rsync options, concatenated, ready for the CLI
      def options
        ([archive, mirror, compress, port] + additional_options).compact.join("\s")
      end

      ##
      # Returns Rsync syntax for specifying the --delete option (to enable mirroring)
      def mirror
        '--delete' if @mirror
      end

      ##
      # Returns Rsync syntax for specifying the the 'compress' option
      def compress
        '-z' if @compress
      end

      ##
      # Returns Rsync syntax for specifying the --archive option
      def archive
        '--archive'
      end

      ##
      # Returns Rsync syntax for specifying a port to connect to
      def port
        "--port='#{@port}'"
      end

      ##
      # If no block has been provided, it'll return the array of @folders.
      # If a block has been provided, it'll evaluate it and add the defined paths to the @folders
      def folders(&block)
        unless block_given?
          return @folders.map do |folder|
            "'#{folder}'"
          end.join("\s")
        end
        instance_eval(&block)
      end

      ##
      # Adds a path to the @folder array
      def add(path)
        @folders << path
      end

    end
  end
end
