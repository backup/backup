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
      attr_accessor :final_file

      def initialize(trigger, procedure)
        self.trigger                = trigger
        self.procedure              = procedure
        self.timestamp              = Time.now.strftime("%Y%m%d%H%M%S")
        self.tmp_path               = File.join(BACKUP_PATH.gsub(' ', '\ '), 'tmp', 'backup', trigger)
        self.encrypt_with_password  = procedure.attributes['encrypt_with_password']
        self.keep_backups           = procedure.attributes['keep_backups']
        create_tmp_folder
      end
      
      # Creates the temporary folder for the specified adapter
      def create_tmp_folder
        %x{ mkdir -p #{tmp_path} }
      end

      # Removes the files inside the temporary folder
      def remove_tmp_files
        %x{ rm #{File.join(tmp_path, '*')} }
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
        case procedure.storage_name.to_sym
          when :s3
            record = Backup::Record::S3.new
            record.load_adapter(self)
            record.save
          when :scp
            record = Backup::Record::SCP.new
            record.load_adapter(self)
            record.save
          when :ftp
            record = Backup::Record::FTP.new
            record.load_adapter(self)
            record.save
          when :sftp
            record = Backup::Record::SFTP.new
            record.load_adapter(self)
            record.save
        end
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