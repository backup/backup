module Backup
  module Connection
    class SSH < Backup::Connection::Base
      
      def initialize(options = {})
        super(options)
      end
      
      # Initializes the transfer to the specified server using SSH.
      # This will first ensure there is a directory, if there is not, a new one will be created
      # After the directory has been confirmed, the transfer process will be initialized.
      def transfer
        %x{ ssh #{options[:ssh][:user]}@#{options[:ssh][:ip]} mkdir -p #{options[:ssh][:path]} }
        %x{ scp #{File.join(options[:backup_path], options[:backup_file])} #{options[:ssh][:user]}@#{options[:ssh][:ip]}:#{options[:ssh][:path]} }
      end

    end
  end 
end