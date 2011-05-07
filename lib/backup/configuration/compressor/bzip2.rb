# encoding: utf-8

module Backup
  module Configuration
    module Compressor
      class Bzip2 < Base
        class << self

          ##
          # Tells Backup::Compressor::Bzip2 to compress
          # better (-9) which is bzip2 default anyway
          attr_accessor :best

          ##
          # Tells Backup::Compressor::Bzip2 to compress
          # faster (-1) (but not significantly faster)
          attr_accessor :fast

        end
      end
    end
  end
end
