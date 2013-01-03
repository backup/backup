  # encoding: utf-8

module Backup
  module Database
    class OpenLDAP < Base

      ##
      # Name of the ldap backup
      attr_accessor :name

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

        @name ||= 'ldap_backup'
        @slapcat_utility  ||= utility(:slapcat)
        @conf_file        ||= '/etc/ldap/ldap.conf'
      end

      ##
      # Performs the mysqldump command and outputs the
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

        pipeline << "cat > '#{ File.join(@dump_path, dump_filename) }.#{ dump_ext }'"

        pipeline.run
        if pipeline.success?
          Logger.message "#{ database_name } Complete!"
        else
          raise Errors::Database::PipelineError,
              "#{ database_name } Dump Failed!\n" +
              pipeline.error_messages
        end
      end

      private

      ##
      # Builds the full mysqldump string based on all attributes
      def slapcat
        "#{ slapcat_utility } -f #{ conf_file } #{ user_options } "
        # "#{ credential_options } #{ connectivity_options } "
      end

      ##
      # Returns the filename to use for dumping the database(s)
      def dump_filename
        name
      end

      def credential_options
        # TODO
      end

      ##
      # Builds the MySQL connectivity options syntax to connect the user
      # to perform the database dumping process
      def connectivity_options
        #TODO
      end

      ##
      # Builds a MySQL compatible string for the additional options
      # specified by the user
      def user_options
        slapcat_args.join(' ')
      end

    end
  end
end