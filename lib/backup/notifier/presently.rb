# encoding: utf-8

Backup::Dependency.load('httparty')

module Backup
  module Notifier
    class Presently < Base

      ##
      # Container for the Presently Client object
      attr_accessor :presently_client

      ##
      # Presently subdomain
      attr_accessor :subdomain

      ##
      # Presently credentials
      attr_accessor :user_name, :password

      ##
      # Group id
      attr_accessor :group_id

      ##
      # Performs the notification
      # Extends from super class. Must call super(model, exception).
      # If any pre-configuration needs to be done,
      # put it above the super(model, exception)
      def perform!(model, exception = false)
        super(model, exception)
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
               when :warning then 'Warning'
               when :failure then 'Failure'
               end
        message = "[Backup::%s] #{model.label} (#{model.trigger})" % name
        presently_client.update(message)
      end

      ##
      # Create a default Presently::Client object
      def set_defaults!
        @presently_client = Client.new(subdomain, user_name, password, group_id)
      end

      class Client
        include HTTParty

        attr_accessor :subdomain, :user_name, :password, :group_id

        def initialize(subdomain, user_name, password, group_id)
          @subdomain = subdomain
          @user_name = user_name
          @password = password
          @group_id = group_id

          self.class.base_uri "https://#{subdomain}.presently.com"
          self.class.basic_auth user_name, password
        end

        def update(message)
          message = "d @#{group_id} #{message}" if group_id
          self.class.post "/api/twitter/statuses/update.json", :body => {
            :status => message,
            :source => "Backup Notifier"
          }
        end
      end
    end
  end
end
