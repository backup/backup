module Backup
  module Adapters
    class Base

      attr_accessor :procedure, :timestamp, :options, :tmp_path, :encrypt_with_password, :keep_backups, :trigger

      # IMPORTANT
      # final_file must have the value of the final filename result
      # so if a file gets compressed, then the file could look like this:
      #   myfile.gz
      #
      # and if a file afterwards gets encrypted, the file will look like:
      #   myfile.gz.enc
      #
      # It is important that, whatever the final filename of the file will be, that :final_file will contain it.
      attr_accessor :performed_file, :compressed_file, :encrypted_file, :final_file

      # Initializes the Backup Process
      # 
      # This will first load in any prefixed settings from the Backup::Adapters::Base
      # Then it will add it's own settings.
      # 
      # First it will call the 'perform' method. This method is concerned with the backup, and must
      # be implemented by derived classes!
      # Then it will optionally encrypt the backed up file
      # Then it will store it to the specified storage location
      # Then it will record the data to the database
      # Once this is all done, all the temporary files will be removed
      # 
      # Wrapped inside of begin/ensure/end block to ensure the deletion of any files in the tmp directory
      def initialize(trigger, procedure)
        self.trigger                = trigger
        self.procedure              = procedure
        self.timestamp              = Time.now.strftime("%Y%m%d%H%M%S")
        self.tmp_path               = File.join(BACKUP_PATH.gsub(' ', '\ '), 'tmp', 'backup', trigger)
        self.encrypt_with_password  = procedure.attributes['encrypt_with_password']
        self.keep_backups           = procedure.attributes['keep_backups']

        self.trigger  = procedure.trigger # is this necessary?

        self.performed_file   = "#{timestamp}.#{trigger.gsub(' ', '-')}.#{performed_file_extension}"
        self.compressed_file  = "#{performed_file}.gz"
        self.encrypted_file   = "#{compressed_file}.enc"
        self.final_file       = compressed_file

        create_tmp_folder
        load_settings
        
        begin
          perform
          encrypt
          store
          record
          notify
        ensure
          remove_tmp_files
        end
      end
      
      # Creates the temporary folder for the specified adapter
      def create_tmp_folder
        %x{ mkdir -p #{tmp_path} }
      end

      # Removes the files inside the temporary folder
      def remove_tmp_files
        %x{ rm #{File.join(tmp_path, '*')} }
      end

      # Encrypts the archive file
      def encrypt
        if encrypt_with_password.is_a?(String)
          puts system_messages[:encrypting]
          %x{ openssl enc -des-cbc -in #{File.join(tmp_path, compressed_file)} -out #{File.join(tmp_path, encrypted_file)} -k #{encrypt_with_password} }
          self.final_file = encrypted_file
        end
      end
      
      # Initializes the storing process depending on the store settings
      # Options:
      #  Amazon (S3)
      #  Remote Server (SCP)
      #  Remote Server (FTP)
      #  Remote Server (SFTP)
      def store
        case procedure.storage_name.to_sym
          when :s3    then Backup::Storage::S3.new(self)
          when :scp   then Backup::Storage::SCP.new(self)
          when :ftp   then Backup::Storage::FTP.new(self)
          when :sftp  then Backup::Storage::SFTP.new(self)
        end
      end
      
      # Records data on every individual file to the database
      def record
        record = case procedure.storage_name.to_sym
          when :s3    then Backup::Record::S3.new
          when :scp   then Backup::Record::SCP.new
          when :ftp   then Backup::Record::FTP.new
          when :sftp  then Backup::Record::SFTP.new
        end
        record.load_adapter(self)
        record.save
      end
      
      # Delivers a notification by email regarding the successfully stored backup
      def notify
        if Backup::Mail::Base.setup?
          Backup::Mail::Base.notify!(self)
        end
      end
      
      def system_messages
        { :compressing  => "Compressing backup..",
          :archiving    => "Archiving backup..",
          :encrypting   => "Encrypting backup..",
          :mysqldump    => "Creating MySQL dump..",
          :pgdump       => "Creating PostgreSQL dump..",
          :commands     => "Executing commands.." }
      end
      
    end
  end
end
