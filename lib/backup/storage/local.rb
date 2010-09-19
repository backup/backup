module Backup
  module Storage
    class Local < Base
      
      # Store on same machine, preferentially in a different hard drive or in 
      # a mounted network path (NFS, Samba, etc)
      attr_accessor :path, :tmp_path, :final_file
      
      # Stores the backup file on local machine
      def initialize(adapter)
        self.path = adapter.procedure.get_storage_configuration.attributes['path']
        self.tmp_path   = adapter.tmp_path
        self.final_file = adapter.final_file
        
        run "mkdir -p #{path}"
        run "cp #{File.join(tmp_path, final_file).gsub('\ ', ' ')} #{File.join(path, final_file)}"
      end
      
    end
  end
end

