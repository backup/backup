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
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path ||= 'backups'

        instance_eval(&block) if block_given?
      end


      private

      ##
      # This is the provider that Fog uses for the Ninefold storage
      def provider
        'Ninefold'
      end

      ##
      # Establishes a connection to Amazon S3
      def connection
        @connection ||= Fog::Storage.new(
          :provider                => provider,
          :ninefold_storage_token  => storage_token,
          :ninefold_storage_secret => storage_secret
        )
      end

      ##
      # Queries the connection for the directory for the given +remote_path+
      # Returns nil if not found, or creates the directory if +create+ is true.
      def directory_for(remote_path, create = false)
        directory = connection.directories.get(remote_path)
        if directory.nil? && create
          directory = connection.directories.create(:key => remote_path)
        end
        directory
      end

      def remote_path_for(package)
        super(package).sub(/^\//, '')
      end

      ##
      # Transfers the archived file to the specified directory
      def transfer!
        remote_path = remote_path_for(@package)

        directory = directory_for(remote_path, true)

        files_to_transfer_for(@package) do |local_file, remote_file|
          Logger.message "#{storage_name} started transferring '#{ local_file }'."

          File.open(File.join(local_path, local_file), 'r') do |file|
            directory.files.create(:key => remote_file, :body => file)
          end
        end
      end

      ##
      # Removes the transferred archive file(s) from the storage location.
      # Any error raised will be rescued during Cycling
      # and a warning will be logged, containing the error message.
      def remove!(package)
        remote_path = remote_path_for(package)

        if directory = directory_for(remote_path)
          not_found = []

          transferred_files_for(package) do |local_file, remote_file|
            Logger.message "#{storage_name} started removing " +
                "'#{ local_file }' from Ninefold."

            if file = directory.files.get(remote_file)
              file.destroy
            else
              not_found << remote_file
            end
          end

          directory.destroy

          unless not_found.empty?
            raise Errors::Storage::Ninefold::NotFoundError, <<-EOS
                The following file(s) were not found in '#{ remote_path }'
                #{ not_found.join("\n") }
            EOS
          end
        else
          raise Errors::Storage::Ninefold::NotFoundError,
              "Directory at '#{remote_path}' not found"
        end
      end

    end
  end
end
