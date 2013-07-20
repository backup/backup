# encoding: utf-8

module Backup
  module Notifier
    class Error < Backup::Error; end

    class Base
      include Backup::Utilities::Helpers
      include Backup::Configuration::Helpers

      ##
      # When set to true, the user will be notified by email
      # when a backup process ends without raising any exceptions
      attr_accessor :on_success
      alias :notify_on_success? :on_success

      ##
      # When set to true, the user will be notified by email
      # when a backup process is successful, but has warnings
      attr_accessor :on_warning
      alias :notify_on_warning? :on_warning

      ##
      # When set to true, the user will be notified by email
      # when a backup process raises an exception before finishing
      attr_accessor :on_failure
      alias :notify_on_failure? :on_failure

      ##
      # Number of times to retry failed attempts to send notification.
      # Default: 10
      attr_accessor :max_retries

      ##
      # Time in seconds to pause before each retry.
      # Default: 30
      attr_accessor :retry_waitsec

      attr_reader :model

      def initialize(model)
        @model = model
        load_defaults!

        @on_success = true if on_success.nil?
        @on_warning = true if on_warning.nil?
        @on_failure = true if on_failure.nil?
        @max_retries    ||= 10
        @retry_waitsec  ||= 30
      end

      # This method is called from an ensure block in Model#perform! and must
      # not raise any exceptions. However, each Notifier's #notify! method
      # should raise an exception if the request fails so it may be retried.
      def perform!
        status = case model.exit_status
                 when 0
                   :success if notify_on_success?
                 when 1
                   :warning if notify_on_success? || notify_on_warning?
                 else
                   :failure if notify_on_failure?
                 end

        if status
          Logger.info "Sending notification using #{ notifier_name }..."
          with_retries { notify!(status) }
        end

      rescue Exception => err
        Logger.error Error.wrap(err, "#{ notifier_name } Failed!")
      end

      private

      def with_retries
        retries = 0
        begin
          yield
        rescue StandardError, Timeout::Error => err
          retries += 1
          raise if retries > max_retries

          Logger.info Error.wrap(err, "Retry ##{ retries } of #{ max_retries }.")
          sleep(retry_waitsec)
          retry
        end
      end

      ##
      # Return the notifier name, with Backup namespace removed
      def notifier_name
        self.class.to_s.sub('Backup::', '')
      end

      # For ruby-1.8.7. Both sorted so specs will match.
      def encode_www_form(enum)
        if RUBY_VERSION < '1.9'
          require 'cgi'
          str = ''
          enum.to_a.map {|k,v| [k.to_s, v] }.sort.each do |k,v|
            str << '&' unless str.empty?
            str << CGI.escape(k) << '=' << CGI.escape(v)
          end
          str
        else
          URI.encode_www_form(enum.sort)
        end
      end

    end
  end
end
