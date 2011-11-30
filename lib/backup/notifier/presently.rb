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
      # If any pre-configuration needs to be done, put it above the super(model, exception)
      def perform!(model, exception = false)
        super(model, exception)
      end

    private

      ##
      # Sends a tweet informing the user that the backup operation
      # proceeded without any errors
      def notify_success!
        presently_client.update("[Backup::Succeeded] #{model.label} (#{ File.basename(Backup::Model.file) })")
      end

      ##
      # Sends a tweet informing the user that the backup operation
      # raised an exception
      def notify_failure!
        presently_client.update("[Backup::Failed] #{model.label} (#{ File.basename(Backup::Model.file) })")
      end

      ##
      # Create a default Presently::Client object
      def set_defaults!
        @presently_client = Client.new subdomain, user_name, password, group_id
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
