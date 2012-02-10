# encoding: utf-8

Backup::Dependency.load('httparty')

module Backup
  module Notifier
    class Presently < Base

      ##
      # Presently subdomain
      attr_accessor :subdomain

      ##
      # Presently credentials
      attr_accessor :user_name, :password

      ##
      # Group id
      attr_accessor :group_id

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
               when :warning then 'Warning'
               when :failure then 'Failure'
               end
        message = "[Backup::%s] #{@model.label} (#{@model.trigger})" % name
        send_message(message)
      end

      def send_message(message)
        client = Client.new(subdomain, user_name, password, group_id)
        client.update(message)
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
