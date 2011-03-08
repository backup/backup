# encoding: utf-8

module Backup
  module Configuration
    module Compressor
      class Gzip < Base
        class << self

          ##
          # Tells Backup::Compressor::Gzip to compress
          # better rather than faster when set to true
          attr_accessor :best

          ##
          # Tells Backup::Compressor::Gzip to compress
          # faster rather than better when set to true
          attr_accessor :fast

        end
      end
    end
  end
end
