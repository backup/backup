# encoding: utf-8

module Backup
  module Database
    class OpenLDAP < Base

      ##
      # Name of the ldap backup
      attr_accessor :name

      ##
      # run slapcat under sudo if needed
      # make sure to set SUID on a file, to let you run the file with permissions of file owner
      # eg. sudo chmod u+s /usr/sbin/slapcat
      attr_accessor :use_sudo

      ##
      # Stores the location of the slapd.conf
      attr_accessor :conf_file

      ##
      # Additional "slapcat" options
      attr_accessor :slapcat_args

      ##
      # Path to slapcat utility (optional)
      attr_accessor :slapcat_utility

      ##
      # Takes the name of the archive and the configuration block
      def initialize(model, &block)
        super(model)

        @slapcat_args     ||= Array.new

        instance_eval(&block) if block_given?

        @name             ||= 'ldap_backup'
        @use_sudo         ||= false
        @slapcat_utility  ||= utility(:slapcat)
        @conf_file        ||= '/etc/ldap/ldap.conf'

      end

      ##
      # Performs the slapcat command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        super

        pipeline = Pipeline.new
        dump_ext = 'ldif'

        pipeline << slapcat
        if @model.compressor
          @model.compressor.compress_with do |command, ext|
            pipeline << command
            dump_ext << ext
          end
        end

        pipeline << "#{ utility(:cat) } > " +
            "'#{ File.join(dump_path, dump_filename) }.#{ dump_ext }'"

        pipeline.run
        if pipeline.success?
          log!(:finished)
        else
          raise Errors, "#{ database_name } Dump Failed!\n" + pipeline.error_messages
        end
      end

      private

      ##
      # Builds the full slapcat string based on all attributes
      def slapcat
        command = "#{ slapcat_utility } -f #{ conf_file } #{ user_options }"
        command.prepend("sudo ") if sudo
        command
      end

      def sudo
        use_sudo
      end

      ##
      # Returns the filename to use for dumping the database(s)
      def dump_filename
        name
      end

      ##
      # Builds a compatible string for the additional options
      # specified by the user
      def user_options
        slapcat_args.join(' ')
      end

    end
  end
end
