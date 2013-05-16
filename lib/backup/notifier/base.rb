# encoding: utf-8

module Backup
  module Notifier
    class Base
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

      attr_reader :model

      def initialize(model)
        @model = model
        load_defaults!

        @on_success = true if on_success.nil?
        @on_warning = true if on_warning.nil?
        @on_failure = true if on_failure.nil?
      end

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
          @template = Backup::Template.new({:model => model})
          Logger.info "Sending notification using #{ notifier_name }..."
          notify!(status)
        end

      rescue Exception => err
        # Notifiers cannot raise any exceptions.
        Logger.error Errors::NotifierError.wrap(err, "#{ notifier_name } Failed!")
      end

      private

      ##
      # Return the notifier name, with Backup namespace removed
      def notifier_name
        self.class.to_s.sub('Backup::', '')
      end

    end
  end
end
