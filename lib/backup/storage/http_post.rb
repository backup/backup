# encoding: utf-8
require 'uri'
require 'json'

module Backup
  module Storage
    class HttpPost < Base

      # ##
      # # URI to post backup to
      # ##
      # attr_accessor :uri

      # ##
      # # Hash of additional HTTP headers to send
      # ##
      # attr_accessor :headers

      # def initialize(model, storage_id = nil)
      #   super
      # end


      ##
      # URI to post notification to.
      #
      # URI scheme may be `http` or `https`.
      #
      # If Basic Authentication is needed, supply the `user:password` in the URI.
      # e.g. 'https://user:pass@www.example.com/path'
      #
      # Port may also be supplied.
      # e.g. 'http://www.example.com:8080/path'
      attr_accessor :uri

      ##
      # Hash of additional HTTP headers to send.
      #
      # This notifier sets the following headers:
      # { 'User-Agent'   => "Backup/#{ Backup::VERSION }",
      #   'Content-Type' => 'x-www-form-urlencoded' }
      #
      # 'Content-Type' may not be changed.
      # 'User-Agent' may be overridden or omitted by setting it to +nil+.
      # e.g. { 'Authorization' => 'my_auth_info', 'User-Agent' => nil }
      attr_accessor :headers

      ##
      # Successful HTTP Status Code(s) that should be returned.
      #
      # This may be a single code or an Array of acceptable codes.
      # e.g. [200, 201, 204]
      #
      # If any other response code is returned, the request will be retried
      # using `max_retries` and `retry_waitsec`.
      #
      # Default: 200
      attr_accessor :success_codes

      ##
      # Verify the server's certificate when using SSL.
      #
      # This will default to +true+ for most systems.
      # It may be forced by setting to +true+, or disabled by setting to +false+.
      attr_accessor :ssl_verify_peer

      ##
      # Path to a +cacert.pem+ file to use for +ssl_verify_peer+.
      #
      # This is provided (via Excon), but may be specified if needed.
      attr_accessor :ssl_ca_file

      def initialize(model, storage_id = nil)
        super

        @headers ||= {}
        @params  ||= {}
        @success_codes ||= 200
      end

      private

      def transfer!

        opts = {
          :headers => { 'User-Agent' => "Backup/#{ VERSION }" }.
              merge(headers).reject {|k,v| v.nil? }.
              merge('Content-Type' => 'application/x-www-form-urlencoded'),
          :expects => success_codes # raise error if unsuccessful
        }
        opts.merge!(:ssl_verify_peer => ssl_verify_peer) unless ssl_verify_peer.nil?
        opts.merge!(:ssl_ca_file => ssl_ca_file) if ssl_ca_file

        # Excon.post(uri, opts)
        
        # POST to create a Backup record
        response = Excon.post(uri, opts)

        timestamp = JSON.parse(response.data[:body])["timestamp"]

        put_url = [uri, timestamp].join("/")

        package.filenames.each do |filename|
          src = "#{ File.join(Config.tmp_path, filename) }"
          # RestClient::Request.execute(:method => :post, :url => uri, :payload => {"backup[file]" => File.new(src, "rb")}, :headers => headers_hash)

          # options = opts.merge("file=#{src}")

          options = opts.merge(:body => URI.encode_www_form({ "file" => src }))

          Excon.put(put_url, options)

          puts src
        end




        # opts = {
        #   :headers => { 'User-Agent' => "Backup/#{ VERSION }" }.
        #       merge(headers).reject {|k,v| v.nil? }.
        #       merge('Content-Type' => 'application/x-www-form-urlencoded'),
        #   :body => URI.encode_www_form({ 'message' => message }),
        #   :expects => success_codes # raise error if unsuccessful
        # }




        # package.filenames.each do |filename|
        #   src = "#{ File.join(Config.tmp_path, filename) }"
        #   headers_hash = { "User-Agent" => "Backup/#{ VERSION }" }.merge(headers).reject {|k,v| v.nil? }
        #   RestClient::Request.execute(:method => :post, :url => uri, :payload => {"backup[file]" => File.new(src, "rb")}, :headers => headers_hash)
        # end

      end

    end
  end
end
