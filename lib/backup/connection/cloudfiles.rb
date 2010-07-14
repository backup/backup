require 'cloudfiles'

module Backup
  module Connection
    class CloudFiles

      attr_accessor :adapter, :procedure, :api_key, :username, :cf_container, :final_file, :tmp_path

      # Initializes the Cloud Files connection, setting the values using the
      # Cloud Files adapter
      def initialize(adapter = false)
        if adapter
          self.adapter            = adapter
          self.procedure          = adapter.procedure
          self.final_file         = adapter.final_file
          self.tmp_path           = adapter.tmp_path.gsub('\ ', ' ')
          load_storage_configuration_attributes
        end
      end

      # Sets values from a procedure, rather than from the adapter object
      def static_initialize(procedure)
        self.procedure = procedure
        load_storage_configuration_attributes(true)
      end

      # Establishes a connection with Rackspace Cloud Files using the
      # credentials provided by the user
      def connect
        connection
      end

      # Wrapper for the Connection object
      def connection
        ::CloudFiles::Connection.new(username, api_key)
      end

      # Wrapper for the Container object
      def container
        connection.container(cf_container)
      end

      # Initializes the file transfer to Rackspace Cloud Files
      # This can only run after a connection has been made using the #connect method
      def store
        object = container.create_object(final_file)
        object.write(open(File.join(tmp_path, final_file)))
      end

      # Destroys file from a bucket on Amazon S3
      def destroy(file, c)
        c = connection.container(c)
        c.delete_object(file)
      end

      private

        def load_storage_configuration_attributes(static = false)
          %w(api_key username).each do |attribute|
            if static
              send("#{attribute}=", procedure.get_storage_configuration.attributes[attribute])
            else
              send("#{attribute}=", adapter.procedure.get_storage_configuration.attributes[attribute])
            end
          end

          if static
            self.cf_container = procedure.get_storage_configuration.attributes['container']
          else
            self.cf_container = adapter.procedure.get_storage_configuration.attributes['container']
          end
        end
    end
  end
end
