Backup::Dependency.load('carrierwave-aliyun')

module Backup
  module Storage
    class OSS < Base
      attr_accessor :bucket,:access_id,:access_key, :path
      
      attr_deprecate "carrierwave-aliyun", :version => '>= 0.1.3'
      
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path ||= 'backups'

        instance_eval(&block) if block_given?
      end
      
      private
      
      def connection
        return @connection if @connection
        opts = {
          :aliyun_access_id => self.access_id,
          :aliyun_access_key => self.access_key, 
          :aliyun_bucket => self.bucket
        }
        @connection = CarrierWave::Storage::Aliyun::Connection.new(opts)
      end
      
      def transfer!
        remote_path = remote_path_for(@package)

        files_to_transfer_for(@package) do |local_file, remote_file|
          Logger.info "#{storage_name} started transferring '#{ local_file }'."
          File.open(File.join(local_path, local_file), 'r') do |file|
            connection.put(File.join(remote_path, remote_file), file.read)
          end
        end
      end
      
      def remove!(package)
        remote_path = remote_path_for(package)

        messages = []
        transferred_files_for(package) do |local_file, remote_file|
          messages << "#{storage_name} started removing " +
              "'#{ local_file }' from Aliyun OSS."
        end
        Logger.info messages.join("\n")

        connection.delete(remote_path)
      end
    end
  end
end