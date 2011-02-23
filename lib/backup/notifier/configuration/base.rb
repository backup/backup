# encoding: utf-8

module Backup
  module Notifier
    module Configuration
      class Base < Backup::Configuration::Base
        class << self

          ##
          # When set to true, the user will be notified by email
          # when a backup process ends without raising any exceptions
          attr_writer :on_success

          ##
          # When set to true, the user will be notified by email
          # when a backup process raises an exception before finishing
          attr_writer :on_failure

        end

        ##
        # When @on_success is nil it means it hasn't been defined
        # and will then default to true
        def self.on_success
          return true if @on_success.nil?
          @on_success
        end

        ##
        # When @on_failure is nil it means it hasn't been defined
        # and will then default to true
        def self.on_failure
          return true if @on_failure.nil?
          @on_failure
        end
      end
    end
  end
end
