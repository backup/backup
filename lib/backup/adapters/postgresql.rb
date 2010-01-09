module Backup
  module Adapters
    class PostgreSQL < Backup::Adapters::Base

      attr_accessor :user, :password, :database, :skip_tables, :host, :port, :socket, :additional_options
      
      private

        # Dumps and Compresses the PostgreSQL file 
        def perform
          log system_messages[:pgdump]; log system_messages[:compressing]
          ENV['PGPASSWORD'] = password
          run "#{pg_dump} -U #{user} #{options} #{additional_options} #{tables_to_skip} #{database} | gzip -f --best > #{File.join(tmp_path, compressed_file)}"
          ENV['PGPASSWORD'] = nil
        end

        def pg_dump
          # try to determine the full path, and fall back to pg_dump if not found
          cmd = `which pg_dump`.chomp
          cmd = 'pg_dump' if cmd.empty?
          cmd
        end
        
        def performed_file_extension
          ".sql"
        end

        # Loads the initial settings
        def load_settings
          %w(user password database skip_tables additional_options).each do |attribute|
            send(:"#{attribute}=", procedure.get_adapter_configuration.attributes[attribute])
          end
          
          %w(host port socket).each do |attribute|
            send(:"#{attribute}=", procedure.get_adapter_configuration.get_options.attributes[attribute])
          end
        end
        
        # Returns a list of options in PostgreSQL syntax
        def options
          options = String.new
          options += " --port='#{port}' "     unless port.blank?
          options += " --host='#{host}' "     unless host.blank?
          options += " --host='#{socket}' "   unless socket.blank?  unless options.include?('--host=')
          options
        end
        
        # Returns a list of tables to skip in PostgreSQL syntax
        def tables_to_skip
          return "" unless skip_tables
          [*skip_tables].map {|table| " -T \"#{table}\" "}
        end

    end
  end
end
