# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::Ninefold class is loaded
Backup::Dependency.load('fog')

module Backup
  module Storage
    class Ninefold < Base

      ##
      # Ninefold Credentials
      attr_accessor :storage_token, :storage_secret

      ##
      # Ninefold directory path
      attr_accessor :path

      ##
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join(path, TRIGGER, @time).sub(/^\//, '')
      end

      ##
      # This is the provider that Fog uses for the Ninefold storage
      def provider
        'Ninefold'
      end

      ##
      # Performs the backup transfer
      def perform!
        super
        transfer!
        cycle!
      end

    private

      ##
      # Set configuration defaults before evaluating configuration block,
      # after setting defaults from Storage::Base
      def pre_configure
        super
        @path ||= 'backups'
      end

      ##
      # Adjust configuration after evaluating configuration block,
      # after adjustments from Storage::Base
      def post_configure
        super
      end

      ##
      # Establishes a connection to Amazon S3 and returns the Fog object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      def connection
        Fog::Storage.new(
          :provider                => provider,
          :ninefold_storage_token  => storage_token,
          :ninefold_storage_secret => storage_secret
        )
      end

      ##
      # Transfers the archived file to the specified directory
      def transfer!
        files_to_transfer do |local_file, remote_file|
          Logger.message "#{storage_name} started transferring '#{ local_file }'."
          directory   = connection.directories.get(remote_path)
          directory ||= connection.directories.create(:key => remote_path)
          directory.files.create(
            :key  => remote_file,
            :body => File.open(File.join(local_path, local_file))
          )
        end
      end

      ##
      # Removes the transferred archive file from the Amazon S3 bucket
      def remove!
        if directory = connection.directories.get(remote_path)
          transferred_files do |local_file, remote_file|
            Logger.message "#{storage_name} started removing " +
                "'#{ local_file }' from Ninefold.'"

            if file = directory.files.get(remote_file)
              file.destroy
            else
              # Note: Fog-0.11.0 will return nil if remote_file is not found
              raise Errors::Storage::Ninefold::NotFoundError,
                  "#{remote_file} not found in #{remote_path}", caller(1)
            end
          end
          directory.destroy
        else
          # Note: Fog-0.11.0 will return nil if remote_path is not found
          raise Errors::Storage::Ninefold::NotFoundError,
              "Directory at #{remote_path} not found", caller(1)
        end
      end

    end
  end
end
