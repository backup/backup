# encoding: utf-8
require 'net/https'

module Backup
  module Notifier
    class PostRequest < Base

      ##
      # The host to send the request to
      attr_accessor :host

      ##
      # The Application Token
      # Defined by the user to possibly separate backup logs
      attr_accessor :token


      def initialize(model, &block)
        super(model)

        instance_eval(&block) if block_given?
      end

      private

      ##
      # Notify the user of the backup operation results.
      # `status` indicates one of the following:
      #
      # `:success`
      # : The backup completed successfully.
      # : Notification will be sent if `on_success` was set to `true`
      #
      # `:warning`
      # : The backup completed successfully, but warnings were logged
      # : Notification will be sent, including a copy of the current
      # : backup log, if `on_warning` was set to `true`
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent, including the Exception which caused
      # : the failure, the Exception's backtrace, a copy of the current
      # : backup log and other information if `on_failure` was set to `true`
      #
      def notify!(status)
        name = case status
               when :success then 'Success'
               when :failure then 'Failure'
               when :warning then 'Warning'
               end
        message = "[Backup::%s] #{@model.label} (#{@model.trigger})" % name

        post(message, status)
      end

      # Send a POST request to the host with a message & status
      def post(message, status)

        # Add the token to the URL if present
        if token
          uri = URI.parse([host, token].join('/'))
        else
          uri = URI.parse(host)
        end

        http_request = Net::HTTP::Post.new(uri.request_uri)
        http_request.initialize_http_header({"User-Agent" => "BackupClient/#{Backup::Version.current}"})

        http_request.set_form_data({:message => message, :status => status, :backup_version => Backup::Version.current})
      
        http = Net::HTTP.new(uri.host, uri.port)
      
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      
        http_result = http.request(http_request)

      end

    end
  end
end