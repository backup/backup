# encoding: utf-8

module Backup
  module Notifier
    class Campfire < Base

      ##
      # Campfire credentials
      attr_accessor :token, :subdomain, :room_id

      ##
      # Container for the Model object
      attr_accessor :model

      ##
      # Instantiates a new Backup::Notifier::Campfire object
      def initialize(&block)
        load_defaults!

        instance_eval(&block) if block_given?

        set_defaults!
      end

      ##
      # Performs the notification
      # Takes an exception object that might've been created if an exception occurred.
      # If this is the case it'll invoke notify_failure!(exception), otherwise, if no
      # error was raised, it'll go ahead and notify_success!
      #
      # If'll only perform these if on_success is true or on_failure is true
      def perform!(model, exception = false)
        @model = model

        if notify_on_success? and exception.eql?(false)
          log!
          notify_success!
        elsif notify_on_failure? and not exception.eql?(false)
          log!
          notify_failure!(exception)
        end
      end

    private

      ##
      # Sends a message informing the user that the backup operation
      # proceeded without any errors
      def notify_success!
        send_message("[Backup::Succeeded] #{model.label} (#{ File.basename(Backup::Model.file) })")
      end

      ##
      # Sends a message informing the user that the backup operation
      # raised an exception
      def notify_failure!(exception)
        send_message("[Backup::Failed] #{model.label} (#{ File.basename(Backup::Model.file) })")
      end

      ##
      # Setting up credentials
      def set_defaults!
        @campfire_client = {:token => @token, :subdomain => @subdomain, :room_id => @room_id}
      end


      private

      def send_message(message)
        room = ::Campfire.room(@campfire_client[:room_id], @campfire_client[:subdomain], @campfire_client[:token])
        room.message message
      end

    end
  end
end
