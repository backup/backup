# encoding: utf-8
require 'faraday'

module Backup
  module Storage
    class Webdav < Base
      include Storage::Cycler

      ##
      # Webdav credentials
      attr_accessor :username, :password

      ##
      # Server hostname and port, SSL settings
      attr_accessor :ip, :port, :use_ssl, :ssl_verify

      ##
      # configure a connection timeout
      attr_accessor :timeout

      def initialize(model, storage_id = nil)
        super

        @port       ||= 80
        @use_ssl    ||= false
        @ssl_verify = true if @ssl_verify.nil?
        @path       ||= 'backups'
        @timeout    ||= nil
        path.sub!(/^~\//, '')
      end

      private

      ##
      # create the connection object used for initializing the requests
      #
      # Note:
      # Webdav has a special HTTP verb for creating collections that needs to
      # be added the the list of allowed verbs in Faraday
      def connection
        if Faraday::Connection.const_defined?(:METHODS)
          Faraday::Connection::METHODS.add(:mkcol)
        end

        conn_hash = {
          url: base_url,
          request: {
            timeout: timeout,
            open_timeout: timeout
          },
          ssl: { verify: ssl_verify }
        }

        Faraday::Connection.new(conn_hash) do |builder|
          builder.request :multipart
          builder.request :basic_auth, username, password
          builder.adapter :net_http
        end
      end

      def base_url
        "#{(use_ssl ? 'https' : 'http')}://#{ip}:#{port}"
      end

      def transfer!
        create_remote_path

        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)

          Logger.info "Storing '#{ ip }:#{ dest }'..."
          connection.put(dest) do |req|
            req.headers['Content-Type'] = 'octet/stream'
            req.headers['Transfer-Encoding'] = 'chunked'
            req.headers['Content-Length'] = File.size(src).to_s
            req.body = Faraday::UploadIO.new(src, 'octet/stream')
          end
        end
      end

      def create_remote_path
        path_parts = Array.new
        remote_path.split('/').each do |path_part|
          path_parts << path_part
          connection.run_request(:mkcol, path_parts.join('/'), nil, nil)
        end
      end

      ##
      # called by the Cycler.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."
        remote_path = remote_path_for(package)
        package.filenames.each do |filename|
          connection.delete(File.join(remote_path, filename))
        end
        connection.delete(File.join(remote_path, ''))
      end
    end
  end
end
