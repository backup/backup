# encoding: utf-8

module Backup
  module Encryptor
    class Base
      include Backup::CLI

      def log!
        Logger.message "#{ self.class } started encrypting the archive."
      end
    end
  end
end
