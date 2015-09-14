# encoding: utf-8
require 'dogapi'

module Backup
  module Notifier
    class DataDog < Base

      ##
      # The DataDog API key
      attr_accessor :api_key

      ##
      # The title of the event
      attr_accessor :title

      attr_deprecate :text,
        :version => '4.2',
        :message => 'Please use the `message` attribute. For more information '\
          'see https://github.com/backup/backup/pull/698'

      ##
      # The timestamp for the event
      attr_accessor :date_happened

      ##
      # The priority of the event (low/normal)
      attr_accessor :priority

      ##
      # The host that generated the event
      attr_accessor :host

      ##
      # The tags for this host (should be an array)
      attr_accessor :tags

      ##
      # The alert_type of the event (error/warning/info/success)
      attr_accessor :alert_type

      ##
      # The aggregation_key for the event
      attr_accessor :aggregation_key

      ##
      # The source_type for the event (nagios, hudson, jenkins, user, my apps, feed, chef, puppet, git, bitbucket, fabric, capistrano)
      attr_accessor :source_type_name

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?
        @title ||= "Backup #{ model.label }"
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
        msg = message.call(model, :status => status_data_for(status))

        hash = { alert_type: default_alert_type(status) }
        hash.store(:msg_title,        @title)
        hash.store(:date_happened,    @date_happened)    if @date_happened
        hash.store(:priority,         @priority)         if @priority
        hash.store(:host,             @host)             if @host
        hash.store(:tags,             @tags)             if @tags
        hash.store(:aggregation_key,  @aggregation_key)  if @aggregation_key
        hash.store(:source_type_name, @source_type_name) if @source_type_name
        hash.store(:alert_type,       @alert_type)       if @alert_type
        send_event(msg, hash)
      end

      # Dogapi::Client will raise an error if unsuccessful.
      def send_event(msg, hash)
        client = Dogapi::Client.new(@api_key)
        event = Dogapi::Event.new(msg, hash)
        client.emit_event(event)
      end

      # set alert type
      def default_alert_type(status)
        case status
        when :success then 'success'
        when :warning then 'warning'
        when :failure then 'error'
        end
      end

    end
  end
end
