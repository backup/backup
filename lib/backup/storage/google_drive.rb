# encoding: utf-8

module Backup
  module Storage
    class GoogleDrive < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      # This adapter uses gdrive (https://github.com/prasmussen/gdrive) to handle all API interactions.
      # Fortunately for us gdrive handles things like timeouts, error retries and large file chunking, too!
      # I found gdrive's defaults to be acceptable, but should be easy to add accessors to customize if needed

      # Path to gdrive executable
      attr_accessor :gdrive_exe

      # Use the gdrive executable to obtain a refresh token. Add that token to your backup model.
      # The gdrive exe will handle refresing the access tokens
      attr_accessor :refresh_token

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil)
        super

        @path           ||= 'backups'
        path.sub!(/^\//, '')

        required = %w{ refresh_token }
        raise Error, "Configuration Error: a refresh_token is required" if refresh_token.nil?

        raise Error, "Configuration Error: gdrive executable is required." if gdrive_exe.nil?
      end

      # private


      ##
      # Transfer each of the package files to Dropbox in chunks of +chunk_size+.
      # Each chunk will be retried +chunk_retries+ times, pausing +retry_waitsec+
      # between retries, if errors occur.
      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ dest }'..."

          parent_id = find_id_from_path(remote_path)
          gdrive_upload(src, parent_id)
        end
      end

      # # Called by the Cycler.
      # # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."
        id = find_id_from_path(remote_path_for(package))
        if id.to_s.empty?
          raise Error, "Backup packge #{ package.time } not found in Google Drive"
        else
          gdrive_delete(id)
        end
      end

      def find_id_from_path(path = remote_path)
        parent = nil
        path.split('/').each do |path_part|
          id = get_folder_id(path_part, parent)
          if id.to_s.empty?
            id = gdrive_mkdir(path_part, parent)
          end
          parent = id
        end
        return parent
      end


      def get_folder_id(name, parent = nil)
        parent = parent ? parent : 'root'
        gdrive_list("name = '#{name}' and '#{parent}' in parents")
      end

      def gdrive_list(query)
        unless query.empty?
          cmd = "gdrive --refresh-token '#{refresh_token}' list --no-header -q \"#{query}\""
          output = `#{cmd}`
          if output.downcase.include? "error"
            raise Error, "Could not list or find the object with query string '#{query}'. gdrive output: #{output}"
          elsif output.empty?
            return nil
          else
            begin
              return /^([^ ]*).*/.match(output)[1] # will return an empty string on no match
            rescue => err
              return nil
            end
          end
        else
          raise Error, "A search query is required to list/find a file or folder"
        end
      end

      def gdrive_mkdir(name, parent = nil)
        unless name.empty?
          parent = parent ? parent : 'root'
          cmd = "gdrive --refresh-token '#{refresh_token}' mkdir -p '#{parent}' '#{name}'"
          output = `#{cmd}`
          if output.downcase.include? "error"
            raise Error, "Could not create the directory '#{name}' with parent '#{parent}'. gdrive output: #{output}"
          else
            id = /^Directory (.*?) created/.match(output)[1]
            raise Error, "Could not determine ID of newly created folder. See gdrive output: #{output}" if id.to_s.empty?
            Logger.info "Created folder #{name} successfully with id '#{id}'"
            return id
          end
        else
          raise Error, "Name parameter is required to make a directory"
        end
      end

      def gdrive_upload(src, parent = nil)
        parent = parent ? parent : 'root'
        cmd = "gdrive --refresh-token '#{refresh_token}' upload -p '#{parent}' '#{src}'"
        output = `#{cmd}`
        if ( ["error", "failed"].any? {|s| output.downcase.include? s } )
          raise Error, "Could not upload file. See gdrive output: #{output}"
        else
          begin
            id = /.*Uploaded (.*?) .*/.match(output)[1]
            raise Error, "empty id" if id.to_s.empty?
            Logger.info "Uploaded #{src} into parent folder '#{parent}' successfully. Google Drive file_id: #{ id }"
          rescue => err
            raise Error.wrap(err, "Could not determine ID of newly created folder. See gdrive output: #{output}")
          end
        end
      end

      def gdrive_delete(id, recursive = true)
        cmd = "gdrive --refresh-token '#{refresh_token}' delete #{'-r' if recursive} '#{id}'"
        output = `#{cmd}`
        if output.downcase.include? "error"
          raise Error, "Could not delete object with id: #{id}. See gdrive output: #{output}"
        else
          Logger.info output
        end
      end
    end
  end
end
