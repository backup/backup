# encoding: utf-8

module Backup
  module Storage
    class Local < Base

      ##
      # Path where the backup will be stored.
      attr_accessor :path

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path ||= File.join(
          File.expand_path(ENV['HOME'] || ''),
          'backups'
        )

        instance_eval(&block) if block_given?

        @path = File.expand_path(@path)
      end

      private

      ##
      # Transfers the archived file to the specified path
      def transfer!
        remote_path = remote_path_for(@package)
        FileUtils.mkdir_p(remote_path)

        files_to_transfer_for(@package) do |local_file, remote_file|
          Logger.message "#{storage_name} started transferring '#{ local_file }'."

          src_path = File.join(local_path, local_file)
          dst_path = File.join(remote_path, remote_file)
          FileUtils.send(transfer_method, src_path, dst_path)
        end
      end

      ##
      # Removes the transferred archive file(s) from the storage location.
      # Any error raised will be rescued during Cycling
      # and a warning will be logged, containing the error message.
      def remove!(package)
        remote_path = remote_path_for(package)

        messages = []
        transferred_files_for(package) do |local_file, remote_file|
          messages << "#{storage_name} started removing '#{ local_file }'."
        end
        Logger.message messages.join("\n")

        FileUtils.rm_r(remote_path)
      end

      ##
      # Set and return the transfer method.
      # If this Local Storage is not the last Storage for the Model,
      # force the transfer to use a *copy* operation and issue a warning.
      def transfer_method
        return @transfer_method if @transfer_method

        if self == @model.storages.last
          @transfer_method = :mv
        else
          Logger.warn Errors::Storage::Local::TransferError.new(<<-EOS)
            Local File Copy Warning!
            The final backup file(s) for '#{@model.label}' (#{@model.trigger})
            will be *copied* to '#{remote_path_for(@package)}'
            To avoid this, when using more than one Storage, the 'Local' Storage
            should be added *last* so the files may be *moved* to their destination.
          EOS
          @transfer_method = :cp
        end
      end

    end
  end
end
