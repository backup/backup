module Backup
  module Connection
    class SSH < Backup::Connection::Base
      
      def initialize(options = {})
        super(options)
      end
      
      def store
        %x{ ssh #{options[:ssh][:user]}@#{options[:ssh][:ip]} mkdir -p #{options[:ssh][:path]} }
        %x{ scp #{File.join(options[:backup_path], options[:backup_file])} #{options[:ssh][:user]}@#{options[:ssh][:ip]}:#{options[:ssh][:path]} }
      end

    end
  end 
end