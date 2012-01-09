# encoding: utf-8

module Backup
  module Configuration
    module Notifier
      class Base < Configuration::Base
        class << self

          ##
          # When set to true, the user will be notified by email
          # when a backup process ends without raising any exceptions
          attr_accessor :on_success

          ##
          # When set to true, the user will be notified by email
          # when a backup process ends successfully, but logged warnings
          attr_accessor :on_warning

          ##
          # When set to true, the user will be notified by email
          # when a backup process raises an exception before finishing
          attr_accessor :on_failure

        end
      end
    end
  end
end
