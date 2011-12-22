# encoding: utf-8

module Backup
  module Configuration
    module Notifier
      class Hipchat < Base
        class << self

          # From
          # Name that appears in Hipchat
          attr_accessor :from

          # Hipchat API Token
          # The token to interact with Hipchat
          attr_accessor :token

          # Rooms
          # Rooms that you want to post notifications to
          attr_accessor :rooms_notified

          # Success Color
          # The background color of a success message. One of :yellow, :red, :green, :purple, or :random. (default: yellow)
          attr_accessor :success_color

          # Warning Color
          # The background color of a success message. One of :yellow, :red, :green, :purple, or :random. (default: yellow)
          attr_accessor :warning_color

          # Failure Color
          # The background color of an error message. One of :yellow, :red, :green, :purple, or :random. (default: yellow)
          attr_accessor :failure_color

          # Notify Users
          # (bool) Notify users in the room
          attr_accessor :notify_users
        end
      end
    end
  end
end

