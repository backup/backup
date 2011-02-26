# encoding: utf-8

module Backup
  module Compressor
    class Base
      include Backup::CLI

      def log!
        Backup::Logger.message "#{ self.class } started compressing the archive."
      end
    end
  end
end
