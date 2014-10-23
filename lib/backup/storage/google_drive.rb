# encoding: utf-8
require 'google/api_client'
require 'mime/types'

Faraday.default_adapter = :excon

module Backup
  module Storage
    class GoogleDrive < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      ##
      # Google Drive API credentials
      attr_accessor :client_id, :client_secret

      ##
      # A Google Drive user must authorize an application to access their
      # Google Drive and obtain an authorization code. Once authorized, the 
      # application can request access tokens using a refresh token. We should
      # provide the ability to read a refresh token from a cache file, or pass 
      # it as an attribute
      attr_accessor :refresh_token, :refresh_token_path

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil)
        super

        @path           ||= 'backups'
        @refresh_token_path     ||= '.refresh_token'
        @max_retries    ||= 10
        @retry_waitsec  ||= 30
        path.sub!(/^\//, '')
      end

      private

      ##
      # To authorize an application for access to a user's Google Drive,
      # an authorization code must be provided in exchange for an 
      # access token and refresh token. The access token can be used
      # immediately for API access, and the refresh token stored to
      # request new access tokens in the future. To obtain the
      # authorization code, a user must visit a URL and grant access
      # to the application. 
      def client
        return @client if @client

        @client = Google::APIClient.new(
          application_name: "Backup ruby gem",
          application_version: Backup::VERSION
        )
        @client.authorization.client_id = client_id
        @client.authorization.client_secret = client_secret
        @client.authorization.scope = 'https://www.googleapis.com/auth/drive'
        @client.authorization.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
        if has_refresh_token?
          @client.authorization.refresh_token = load_refresh_token
          @client.authorization.fetch_access_token!
        else
          @client = authorize_application(@client)
          @client.authorization.fetch_access_token!
          save_refresh_token(@client)
        end

        @client
        rescue => err
          raise Error.wrap(err, 'Authorization Failed')
      end

      # ##
      # # Return refresh_token from attribute or file
      def load_refresh_token
        if refresh_token
          token = refresh_token
        else
          if File.exist?(refresh_token_path)
            token = File.read(refresh_token_path)
            Logger.info "Refresh token loaded from cache!"
          end
        end
        token
      rescue => err
            Logger.warn Error.wrap(err, <<-EOS)
              Could not read refresh token from cache.
            EOS
      end


      # ##
      # # Does the user have a refresh token yet?
      def has_refresh_token?
        (refresh_token || File.exist?(refresh_token_path))
      end


      # ##
      # # Save refresh token to file for later user
      def save_refresh_token(client)
        token = client.authorization.refresh_token        
        puts "For reference, your refresh token is: #{token}"
        puts "\t and was saved to: #{refresh_token_path}"

        File.open(refresh_token_path, 'w') do |f| 
          f.write(client.authorization.refresh_token)
        end

        rescue => err
          Logger.warn Error.wrap(err, <<-EOS)
              Could not write refresh token to cache file
          EOS
      end


      # ##
      # # Send the user to a URL to grant access to the application
      # # Returns the authorized client
      def authorize_application(client)
        url = client.authorization.authorization_uri(access_type: :offline)
        puts "Please visit the following URL to obtain an authorization code. Paste it at the prompt to obtain tokens."
        puts "\t#{url}"
        puts "\n"
        $stdout.write  "Enter authorization code: "
        client.authorization.code = $stdin.gets.chomp
        client
      end


      ##
      # Transfer each of the package files to Dropbox in chunks of +chunk_size+.
      # Each chunk will be retried +chunk_retries+ times, pausing +retry_waitsec+
      # between retries, if errors occur.
      def transfer!
        

        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ dest }'..."


          file = client.discovered_api('drive', 'v2').files.insert.request_schema.new({
            'title' => filename,
            'parents' => [{'id' => remote_path_id}]
          })

          mime = MIME::Types.type_for(src).first.to_s || "*/*"

          media = Google::APIClient::UploadIO.new(src, mime)

          result = client.execute(
            :api_method => client.discovered_api('drive', 'v2').files.insert,
            :body_object => file,
            :media => media,
            :parameters => {
              'uploadType' => 'resumable',
              'alt' => 'json'}
          )

          result.resumable_upload.send_all(client)

          with_retries do
            if !result.resumable_upload.complete? && !result.resumable_upload.expired?
              client.execute(result.resumable_upload) # Continue sending... 
            end
          end
        end

        rescue => err
          raise Error.wrap(err, 'Upload Failed!')
      end

      def with_retries
        retries = 0
        begin
          yield
        rescue StandardError => err
          retries += 1
          raise if retries > max_retries

          Logger.info Error.wrap(err, "Retry ##{ retries } of #{ max_retries }.")
          sleep(retry_waitsec)
          retry
        end
      end

      # # Called by the Cycler.
      # # Any error raised will be logged as a warning.
      def remove!(package)
        file_id = remote_path_id(remote_path_for(package), false)
        if file_id
          Logger.info "Deleting #{remote_path_for(package)} with Google Drive fileId: #{file_id}"
          request = Google::APIClient::Request.new({
            api_method: client.discovered_api('drive', 'v2').files.delete,
            parameters: {
              fileId: file_id,
            }
          })
          client.execute(request)
        else
          Logger.warn "Remote path #{remote_path_for(package)} not found."
        end
      end

      def remote_path_id(path = remote_path, create = true)
        folder_id = nil
        path.split('/').each do |path_part|
          begin
            folder_id = find_folder(path_part, folder_id, create)
          rescue => err
            raise Error.wrap(err, 'Unable to create a required parent folder')
          end
        end
        folder_id
      end

      def get_file_id(file_path)
        folder_id = nil
        File.dirname(remote_path).split('/').each do |path_part|
          begin
            folder_id = find_folder(path_part, folder_id, false)
          rescue => err
            raise Error.wrap(err, "Unable to find folder in #{remote_path}")
          end
        end

        request = Google::APIClient::Request.new({
          api_method: client.discovered_api('drive', 'v2').children.list,
          parameters: {
            folderId: folder_id,
            q: "title = #{File.basename(remote_path)} and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
          }
        })
        result = client.execute(request)
        if result.data.items && result.data.items.length > 0
          # Google Drive allows files with the same title. Return only the first result
          result.data.items[0].id
        else
          nil
        end
      end

      def find_folder(title, parent_id = 'root', create = true)
        parent_id = 'root' unless parent_id # catch nil cases

        request = Google::APIClient::Request.new({
          api_method: client.discovered_api('drive', 'v2').children.list,
          parameters: {
            folderId: parent_id,
            q: "title = '#{title}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
          }
        })
        result = client.execute(request)
        if result.data.items && result.data.items.length > 0
          # Google Drive allows files with the same title. Return only the first result
          result.data.items[0].id
        else
          if create
            begin
              folder = client.discovered_api('drive', 'v2').files.insert.request_schema.new({
                title: title,
                parents: [ { id: parent_id } ],
                mimeType: 'application/vnd.google-apps.folder'
              })

              request = Google::APIClient::Request.new({
                :api_method => client.discovered_api('drive', 'v2').files.insert,
                :body_object => folder
              })
              result = client.execute(request)
              result.data.id
            rescue => err
              raise Error.wrap(err, 'Unable to create a required parent folder')
            end
          else
            nil
          end
        end
      end
    end
  end
end
