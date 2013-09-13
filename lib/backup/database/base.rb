# encoding: utf-8

module Backup
  module Database
    class Error < Backup::Error; end

    class Base
      include Backup::Utilities::Helpers
      include Backup::Configuration::Helpers

      attr_reader :model, :database_id, :dump_path

      ##
      # If given, +database_id+ will be appended to the #dump_filename.
      # This is required if multiple Databases of the same class are added to
      # the model.
      def initialize(model, database_id = nil)
        @model = model
        @database_id = database_id.to_s.gsub(/\W/, '_') if database_id
        @dump_path = File.join(Config.tmp_path, model.trigger, 'databases')
        load_defaults!
      end

      def perform!
        log!(:started)
        prepare!
      end

      private

      def prepare!
        FileUtils.mkdir_p(dump_path)
      end

      ##
      # Sets the base filename for the final dump file to be saved in +dump_path+,
      # based on the class name. e.g. databases/MySQL.sql
      #
      # +database_id+ will be appended if it is defined.
      # e.g. databases/MySQL-database_id.sql
      #
      # If multiple Databases of the same class are defined and no +database_id+
      # is defined, the user will be warned and one will be auto-generated.
      #
      # Model#initialize calls this method *after* all defined databases have
      # been initialized so `backup check` can report these warnings.
      def dump_filename
        @dump_filename ||= begin
          unless database_id
            if model.databases.select {|d| d.class == self.class }.count > 1
              sleep 1; @database_id = Time.now.to_i.to_s[-5, 5]
              Logger.warn Error.new(<<-EOS)
                Database Identifier Missing
                When multiple Databases are configured in a single Backup Model
                that have the same class (MySQL, PostgreSQL, etc.), the optional
                +database_id+ must be specified to uniquely identify each instance.
                e.g. database MySQL, :database_id do |db|
                This will result in an output file in your final backup package like:
                databases/MySQL-database_id.sql

                Backup has auto-generated an identifier (#{ database_id }) for this
                database dump and will now continue.
              EOS
            end
          end

          self.class.name.split('::').last + (database_id ? "-#{ database_id }" : '')
        end
      end

      def database_name
        @database_name ||= self.class.to_s.sub('Backup::', '') +
            (database_id ? " (#{ database_id })" : '')
      end

      def log!(action)
        msg = case action
              when :started then 'Started...'
              when :finished then 'Finished!'
              end
        Logger.info "#{ database_name } #{ msg }"
      end
    end
  end
end
