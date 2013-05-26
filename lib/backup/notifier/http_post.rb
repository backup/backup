# encoding: utf-8
require 'uri'

module Backup
  module Notifier
    class HttpPost < Base

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
      # Hash of additional POST parameters to send.
      #
      # This notifier will set two parameters:
      # { 'status'  => 'success|warning|failure',
      #   'message' => '[Backup::(Success|Warning|Failure)] label (trigger)' }
      #
      # 'status' may not be changed.
      # 'message' may be overridden or omitted by setting a +nil+ value.
      # e.g. { 'auth_token' => 'my_token', 'message' => nil }
      attr_accessor :params

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

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?

        @headers ||= {}
        @params  ||= {}
        @success_codes ||= 200
      end

      private

      ##
      # Notify the user of the backup operation results.
      #
      # `status` indicates one of the following:
      #
      # `:success`
      # : The backup completed successfully.
      # : Notification will be sent if `on_success` is `true`.
      #
      # `:warning`
      # : The backup completed successfully, but warnings were logged.
      # : Notification will be sent if `on_warning` or `on_success` is `true`.
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent if `on_warning` or `on_success` is `true`.
      #
      def notify!(status)
        tag = case status
              when :success then '[Backup::Success]'
              when :failure then '[Backup::Failure]'
              when :warning then '[Backup::Warning]'
              end
        message = "#{ tag } #{ model.label } (#{ model.trigger })"

        opts = {
          :headers => { 'User-Agent' => "Backup/#{ VERSION }" }.
              merge(headers).reject {|k,v| v.nil? }.
              merge('Content-Type' => 'application/x-www-form-urlencoded'),
          :body => encode_www_form({ 'message' => message }.
              merge(params).reject {|k,v| v.nil? }.
              merge('status' => status.to_s)),
          :expects => success_codes # raise error if unsuccessful
        }
        opts.merge!(:ssl_verify_peer => ssl_verify_peer) unless ssl_verify_peer.nil?
        opts.merge!(:ssl_ca_file => ssl_ca_file) if ssl_ca_file

        Excon.post(uri, opts)
      end

    end
  end
end
