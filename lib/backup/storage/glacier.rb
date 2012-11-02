# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::Glacier class is loaded
Backup::Dependency.load('fog')

module Backup
  module Storage
    class Glacier < Base

      ##
      # Amazon Glacier Credentials
      attr_accessor :access_key_id, :secret_access_key

      ##
      # Amazon Glacier vault name
      attr_accessor :vault

      ##
      # Region of the specified Glacier vault
      attr_accessor :region

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path ||= 'backups'

        instance_eval(&block) if block_given?
      end

      private

      ##
      # Establishes a connection to Amazon Glacier
      def connection
        @connection ||= Fog::AWS::Glacier.new(
          :aws_access_key_id      => access_key_id,
          :aws_secret_access_key  => secret_access_key,
          :region                 => region
        )
      end

      # a classic constant-time method of calculating nearest-larger power of two
      # http://jeffreystedfast.blogspot.com/2008/06/calculating-nearest-power-of-2.html
      # (will be) used for calculating multipart chunk size
      def nearest_power_of_two(to_number)
        n = (to_number > 0 ? (to_number - 1) : 0)

        n = n | n >> 1
        n = n | n >> 2
        n = n | n >> 4
        n = n | n >> 8
        n = n | n >> 16
        n = n + 1
        n
      end

      ##
      # Transfers the archived file to the specified Amazon Glacier vault
      def transfer!
        # Fog::AWS::Glacier::Real does not support sync_clock

        v = connection.vaults.get(vault)

        files_to_transfer_for(@package) do |local_file, remote_file|
          Logger.message "#{storage_name} started transferring " +
              "'#{ local_file }' to vault '#{ vault }'."

          # with 10k chunks per upload limit, a 1MB chunk means 10GB file size limit
          # TODO: count dynamically to allow archiving of larger files
          # (100MB should be the threshold)
          file_size = File.size(File.join(local_path, local_file))
          chunk_size = 1024*1024

          File.open(File.join(local_path, local_file), 'r') do |file|
            v.archives.create(:body => file, :description => "#{local_file}", :multipart_chunk_size => chunk_size)
          end
        end
      end

      ##
      # Removes the transferred archive file(s) from the storage location.
      # Any error raised will be rescued during Cycling
      # and a warning will be logged, containing the error message.
      def remove!(package)
        Logger.message "#{storage_name} does not support removing files (yet)"
      end

    end
  end
end
