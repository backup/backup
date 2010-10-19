require 'tempfile'

module Backup
  module Adapters
    class Base

      include Backup::CommandHelper
      
      attr_accessor :procedure, :timestamp, :options, :tmp_path, :encrypt_with_password, :encrypt_with_gpg_public_key, :keep_backups, :trigger

      # IMPORTANT
      # final_file must have the value of the final filename result
      # so if a file gets compressed, then the file could look like this:
      #   myfile.gz
      #
      # and if a file afterwards gets encrypted, the file will look like:
      #   myfile.gz.enc (with a password)
      #   myfile.gz.gpg (with a gpg public key)
      #
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
        self.trigger                     = trigger
        self.procedure                   = procedure
        self.timestamp                   = Time.now.strftime("%Y%m%d%H%M%S")
        self.tmp_path                    = File.join(BACKUP_PATH.gsub(' ', '\ '), 'tmp', 'backup', trigger)
        self.encrypt_with_password       = procedure.attributes['encrypt_with_password']
        self.encrypt_with_gpg_public_key = procedure.attributes['encrypt_with_gpg_public_key']
        self.keep_backups                = procedure.attributes['keep_backups']

        self.performed_file   = "#{timestamp}.#{trigger.gsub(' ', '-')}#{performed_file_extension}"
        self.compressed_file  = "#{performed_file}.gz"
        self.final_file       = compressed_file

        begin
          create_tmp_folder
          load_settings # if respond_to?(:load_settings)
          handle_before_backup
          perform
          encrypt
          store
          handle_after_backup
          record
          notify
        ensure
          remove_tmp_files
        end
      end
      
      # Creates the temporary folder for the specified adapter
      def create_tmp_folder
        #need to create with universal privlages as some backup tasks might create this path under sudo
        run "mkdir -m 0777 -p #{tmp_path.sub(/\/[^\/]+$/, '')}"  #this is the parent to the tmp_path
        run "mkdir -m 0777 -p #{tmp_path}"                       #the temp path dir
      end
      
      # TODO make methods in derived classes public? respond_to cannot identify private methods
      def load_settings
      end
      
      def skip_backup(msg)
        log "Terminating backup early because: #{msg}"
        exit 1
      end

      # Removes the files inside the temporary folder
      def remove_tmp_files
        run "rm -r #{File.join(tmp_path)}" if File.exists?(tmp_path) #just in case there isn't one because the process was skipped
      end
      
      def handle_before_backup
        return unless self.procedure.before_backup_block
        log system_messages[:before_backup_hook]
        #run it through this instance so the block is run as a part of this adapter...which means it has access to all sorts of sutff
        self.instance_eval &self.procedure.before_backup_block
      end
      
      def handle_after_backup
        return unless self.procedure.after_backup_block
        log system_messages[:after_backup_hook]
        #run it through this instance so the block is run as a part of this adapter...which means it has access to all sorts of sutff
        self.instance_eval &self.procedure.after_backup_block
      end

      # Encrypts the archive file
      def encrypt
        if encrypt_with_gpg_public_key.is_a?(String) && encrypt_with_password.is_a?(String)
          puts "both 'encrypt_with_gpg_public_key' and 'encrypt_with_password' are set.  Please choose one or the other.  Exiting."
          exit 1
        end
        
        if encrypt_with_gpg_public_key.is_a?(String)
          if `which gpg` == ''
            puts "Encrypting with a GPG public key requires that gpg be in your public path.  gpg was not found.  Exiting"
            exit 1
          end
          log system_messages[:encrypting_w_key]
          self.encrypted_file   = "#{self.final_file}.gpg"

          # tmp_file = Tempfile.new('backup.pub'){ |tmp_file| tmp_file << encrypt_with_gpg_public_key }
          tmp_file = Tempfile.new('backup.pub')
          tmp_file << encrypt_with_gpg_public_key
          tmp_file.close       
          # that will either say the key was added OR that it wasn't needed, but either way we need to parse for the uid
          # which will be wrapped in '<' and '>' like <someone_famous@me.com>
          encryptionKeyId = `gpg --import #{tmp_file.path} 2>&1`.match(/<(.+)>/)[1] 
          run "gpg -e --trust-model always -o #{File.join(tmp_path, encrypted_file)} -r '#{encryptionKeyId}' #{File.join(tmp_path, compressed_file)}"
        elsif encrypt_with_password.is_a?(String)
          log system_messages[:encrypting_w_pass]
          self.encrypted_file   = "#{self.final_file}.enc"
          run "openssl enc -des-cbc -in #{File.join(tmp_path, compressed_file)} -out #{File.join(tmp_path, encrypted_file)} -k #{encrypt_with_password}"
        end
        self.final_file = encrypted_file if encrypted_file
      end
      
      # Initializes the storing process
      def store
        procedure.initialize_storage(self)
      end
      
      # Records data on every individual file to the database
      def record
        record = procedure.initialize_record
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
        { :compressing        => "Compressing backup..",
          :archiving          => "Archiving backup..",
          :encrypting_w_pass  => "Encrypting backup with password..",
          :encrypting_w_key   => "Encrypting backup with gpg public key..",
          :mysqldump          => "Creating MySQL dump..",
          :mongo_dump         => "Creating MongoDB dump..",
          :mongo_copy         => "Creating MongoDB disk level copy..",
          :before_backup_hook => "Running before backup hook..",
          :after_backup_hook  => "Running after backup hook..",
          :pgdump             => "Creating PostgreSQL dump..",
          :sqlite             => "Copying and compressing SQLite database..",
          :commands           => "Executing commands.." }
      end
      
    end
  end
end
