# encoding: utf-8

module Backup
  module Configuration
    module Compressor
      class Lzma < Base
        class << self

          ##
          # Tells Backup::Compressor::Lzma to compress
          # better (--best) which is lzma default anyway
          attr_accessor :best

          ##
          # Tells Backup::Compressor::Lzma to compress
          # faster (--fast) (but not significantly faster)
          attr_accessor :fast

        end
      end
    end
  end
end
