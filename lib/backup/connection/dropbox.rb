require 'dropbox'

module Backup
  module Connection
    class Dropbox

      attr_accessor :adapter, :procedure, :final_file, :tmp_path, :api_key, :secret_access_key, :username, :password, :path

      def initialize(adapter=false)
        if adapter
          self.adapter            = adapter
          self.procedure          = adapter.procedure
          self.final_file         = adapter.final_file
          self.tmp_path           = adapter.tmp_path.gsub('\ ', ' ')

          load_storage_configuration_attributes
        end
      end

      def static_initialize(procedure)
        self.procedure = procedure
        load_storage_configuration_attributes(true)
      end

      def session
        @session ||= ::Dropbox::Session.new(api_key, secret_access_key)
        unless @session.authorized?
          @session.authorizing_user = username
          @session.authorizing_password = password
          @session.authorize!
        end

        @session
      end

      def connect
        session
      end

      def path
        @path || "backups"
      end

      def store
        path_to_file = File.join(tmp_path, final_file)
        session.upload(path_to_file, path, :mode => :dropbox)
      end

      private

      def load_storage_configuration_attributes(static=false)
        %w(api_key secret_access_key username password path).each do |attribute|
          if static
            send("#{attribute}=", procedure.get_storage_configuration.attributes[attribute])
          else
            send("#{attribute}=", adapter.procedure.get_storage_configuration.attributes[attribute])
          end
        end
      end
    end
  end
end
