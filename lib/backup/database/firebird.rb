# encoding: utf-8

module Backup
  module Database
    class Firebird < Base
      class Error < Backup::Error; end

      ##
      # Name of the database that needs to get dumped.
      attr_accessor :name

      ##
      # Credentials for the specified database
      attr_accessor :username, :password

      ##
      # If the gbak needs to be executed as a sudo user
      attr_accessor :sudo_user

      ##
      # Connectivity options
      attr_accessor :host, :path

      ##
      # Additional "gbak" options
      attr_accessor :additional_options

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?
      end

      ##
      # Performs the gbak command and outputs the dump file
      # in the +dump_path+ using +dump_filename+.
      #
      #   <trigger>/databases/Firebird[-<database_id>].fbk[.gz]
      def perform!
        super

        dump_file = "#{ File.join(dump_path, dump_filename) }.fbk"

        run "#{ gbak } '#{ dump_file }'"

        model.compressor.compress_with do |command, ext|
          run "#{ command } -c '#{ dump_file }' > '#{ dump_file + ext }'"
          FileUtils.rm_f dump_file
        end if model.compressor

        log!(:finished)
      end

      def gbak
        "#{ sudo_option }" +
        "#{ utility(:gbak) } " +
        "'#{ connectivity_options }#{ name }' " +
        "#{ username_option } #{ password_option } " +
        "#{ user_options }"
      end

      def username_option
        "-user #{ username }" if username
      end

      def password_option
        "-pas #{ password }" if password
      end

      def sudo_option
        "#{ utility(:sudo) } -n -u #{ sudo_user } " if sudo_user
      end

      def connectivity_options
        connectivity = ''

        connectivity << "#{ host }:" if host
        connectivity << path if path

        connectivity
      end

      def user_options
        Array(additional_options).join(' ')
      end
    end
  end
end
