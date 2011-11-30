# encoding: utf-8

module Backup
  module Configuration
    module Compressor
      class Pbzip2 < Base
        class << self

          ##
          # Tells Backup::Compressor::Pbzip2 to compress
          # better (-9) which is bzip2 default anyway
          attr_accessor :best

          ##
          # Tells Backup::Compressor::Pbzip2 to compress
          # faster (-1) (but not significantly faster)
          attr_accessor :fast

          ##                                                                                                                                                                         
          # Tells Backup::Compressor::Pbzip2 how many processors                                                                                                                     
          # use, by default autodetect is used                                                                                                                                       
          attr_writer :processors

        end
      end
    end
  end
end
