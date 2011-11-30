# encoding: utf-8

##
# If the Ruby version of this process is 1.8.x or less
# then use the JSON gem. Otherwise if the current process is running
# Ruby 1.9.x or later then it is built in and we can load it from the Ruby core lib
if RUBY_VERSION < '1.9.0'
  Backup::Dependency.load('json')
else
  require 'json'
end

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

      ##
      # Performs the notification
      # Extends from super class. Must call super(model, exception).
      # If any pre-configuration needs to be done, put it above the super(model, exception)
      def perform!(model, exception = false)
        super(model, exception)
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
        @campfire_client = {
          :api_token => @api_token,
          :subdomain => @subdomain,
          :room_id   => @room_id
        }
      end

      ##
      # Creates a new Campfire::Interface object and passes in the
      # campfire clients "room_id", "subdomain" and "api_token". Using this object
      # the provided "message" will be sent to the desired Campfire chat room
      def send_message(message)
        room = Interface.room(
          @campfire_client[:room_id],
          @campfire_client[:subdomain],
          @campfire_client[:api_token]
        )
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
          post 'speak', :body => {
            :message => {
              :body => message,
              :type => type
            }
          }.to_json
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
