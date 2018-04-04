# encoding: utf-8

module Backup
  module Database
    class Neo4j < Base
      class Error < Backup::Error; end

      ##
      # Connectivity options for the +neo4j-backup+ utility.
      attr_accessor :host, :port, :incremental_backup_path

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?
      end

      def perform!
        super
        dump!
        package!
      end

      private

      ##
      # Performs all required neo4j-backup commands, dumping the output files
      # into the +dump_packaging_path+ directory for packaging.
      def dump!
        FileUtils.mkdir_p incremental_backup_path
        run(neo4j_backup)
        FileUtils.copy_entry incremental_backup_path, dump_path
      end

      ##
      # Creates a tar archive of the +dump_packaging_path+ directory
      # and stores it in the +dump_path+ using +dump_filename+.
      #
      #   <trigger>/databases/Neo4j[-<database_id>].tar[.gz]
      #
      # If successful, +dump_packaging_path+ is removed.
      def package!
        pipeline = Pipeline.new
        dump_ext = 'tar'

        pipeline << "#{ utility(:tar) } -cf - " +
            "-C '#{ dump_path }' '#{ dump_filename }'"

        model.compressor.compress_with do |command, ext|
          pipeline << command
          dump_ext << ext
        end if model.compressor

        pipeline << "#{ utility(:cat) } > " +
            "'#{ File.join(dump_path, dump_filename) }.#{ dump_ext }'"

        pipeline.run
        if pipeline.success?
          FileUtils.rm_rf dump_packaging_path
          log!(:finished)
        else
          raise Error, "Dump Failed!\n" + pipeline.error_messages
        end
      end

      def dump_packaging_path
        File.join(dump_path, dump_filename)
      end

      # Neo4j detects if a previous backup has been performed, and
      # performs an incremental backup on that path.
      # If not set, does not do incremental backups.
      def incremental_backup_path
        @incremental_backup_path ||= dump_packaging_path
      end

      def neo4j_backup
        "#{ utility('neo4j-backup') } " +
        "#{ connectivity_options } -to '#{ incremental_backup_path }'"
      end

      def connectivity_options
        opts = []
        opts << "-host '#{ host }'" if host
        opts << "-port '#{ port }'" if port
        opts.join(' ')
      end
    end
  end
end
