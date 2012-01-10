# encoding: utf-8

module Backup
  module Syncer
    class Base
      include Backup::CLI::Helpers
      include Backup::Configuration::Helpers

      private

      def syncer_name
        self.class.to_s.sub('Backup::', '')
      end

    end
  end
end
