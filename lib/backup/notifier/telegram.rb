# encoding: utf-8
require 'uri'

module Backup
  module Notifier
    class Telegram < Base

      ##
      # To send notifications via Telegram you need:
      # 1. a bot who will send messages (created with the help of @BotFather bot via any Telegram client);
      # 2. a public channel messages will be sent to (channels are created via any Telegram client generally by starting a new message and selecting ‘New Channel’);
      # 3. add your bot to your channel as an administrator (only administrators can post messages to public channels)
      # You can also use a private channel or chat/group chat, but obtaininig chat id for it is a bit more complicated
      # (search for stackoverflow question: "How to obtain the chat_id of a private Telegram channel?")
      # Also please note that bots can not initiate conversations in Telegram, so your bot has to be manually added to channel/chat/group chat before it can send messages there.

      ##
      # Bot authentication token (will be given on bot creation)
      attr_accessor :bot_token

      ##
      # Unique identifier for the target chat or username of the target channel (in the format @channelusername)
      attr_accessor :chat_id

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?
      end

      private

      ##
      # Notify the user of the backup operation results.
      #
      # `status` indicates one of the following:
      #
      # `:success`
      # : The backup completed successfully.
      # : Notification will be sent if `on_success` is `true`.
      #
      # `:warning`
      # : The backup completed successfully, but warnings were logged.
      # : Notification will be sent if `on_warning` or `on_success` is `true`.
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent if `on_warning` or `on_success` is `true`.
      #
      def notify!(status)
        send_message(message.call(model, :status => status_data_for(status)))
      end

      def send_message(message)
        uri = "https://api.telegram.org/bot#{ bot_token }/sendMessage"
        data = {
          :chat_id  => chat_id,
          :text     => message
        }
        options = {
          :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded' },
          :body     => URI.encode_www_form(data)
        }
        options.merge!(:expects => 200) # raise error if unsuccessful
        Excon.post(uri, options)
      end

    end
  end
end
