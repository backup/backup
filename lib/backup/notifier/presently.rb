# encoding: utf-8

Backup::Dependency.load('httparty')

module Backup
  module Notifier
    class Presently < Base

      ##
      # Container for the Presently Client object
      attr_accessor :presently_client

      ##
      # Container for the Model object
      attr_accessor :model

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
      # Instantiates a new Backup::Notifier::Presently object
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
      # Sends a tweet informing the user that the backup operation
      # proceeded without any errors
      def notify_success!
        presently_client.update("[Backup::Succeeded] #{model.label} (#{ File.basename(Backup::Model.file) })")
      end

      ##
      # Sends a tweet informing the user that the backup operation
      # raised an exception
      def notify_failure!(exception)
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
