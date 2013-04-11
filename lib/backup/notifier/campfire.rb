# encoding: utf-8

##
# Load the HTTParty library from the gem
Backup::Dependency.load('httparty')

module Backup
  module Notifier
    class Campfire < Base

      ##
      # Campfire api authentication token
      attr_accessor :api_token

      ##
      # Campfire account's subdomain
      attr_accessor :subdomain

      ##
      # Campfire account's room id
      attr_accessor :room_id

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

      ##
      # Creates a new Campfire::Interface object and passes in the
      # campfire clients "room_id", "subdomain" and "api_token". Using this object
      # the provided "message" will be sent to the desired Campfire chat room
      def send_message(message)
        room = Interface.room(room_id, subdomain, api_token)
        room.message(message)
      end

      ##
      # The Campfire::Interface acts as the Interface for the Campfire class.
      # It uses the HTTParty library and the Campfire::Room class to communicate
      # with the Campfire rooms. HTTParty provides the Campfire::Interface with the methods
      # necessary to communicate (inside the HTTParty module) such as the class methods:
      # * post
      # * base_uri
      # * basic_auth
      class Interface
        include HTTParty

        ##
        # We communicate using the JSON data format
        headers 'Content-Type' => 'application/json'

        ##
        # Instantiates a new Campfire::Room object with
        # the provided arguments and returns this object
        def self.room(room_id, subdomain, api_token)
          Room.new(room_id, subdomain, api_token)
        end
      end

      ##
      # The Campfire::Room acts as a model for an actual room on the Campfire service.
      # And it uses the Campfire::Interface's (HTTParty) class methods to communicate based
      # on the provided parameters (room_id, subdomain and api_token)
      class Room

        ##
        # Campfire api authentication api_token
        attr_accessor :api_token

        ##
        # Campfire account's subdomain
        attr_accessor :subdomain

        ##
        # Campfire account's room id
        attr_accessor :room_id

        ##
        # Instantiates a new Campfire::Room object and sets all the
        # necessary arguments (@room_id, @subdomain, @api_token)
        def initialize(room_id, subdomain, api_token)
          @room_id   = room_id
          @subdomain = subdomain
          @api_token = api_token
        end

        ##
        # Wrapper method for the #send_message (private) method
        def message(message)
          send_message(message)
        end

        private

        ##
        # Takes a "message" as argument, the "type" defaults to "Textmessage".
        # This method builds up a POST request with the necessary params (serialized to JSON format)
        # and sends it to the Campfire service in order to submit the message
        def send_message(message, type = 'Textmessage')
          post 'speak', :body => MultiJson.encode(
            { :message => { :body => message, :type => type } }
          )
        end

        ##
        # Builds/sets up the Campfire::Interface attributes and submits
        # the POST request that was built in the #send_message (private) method
        def post(action, options = {})
          Interface.base_uri("https://#{subdomain}.campfirenow.com")
          Interface.basic_auth(api_token, 'x')
          Interface.post(room_url_for(action), options)
        end

        ##
        # Returns the url for the specified room (in JSON format)
        def room_url_for(action)
          "/room/#{room_id}/#{action}.json"
        end
      end

    end
  end
end
