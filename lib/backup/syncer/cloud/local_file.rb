# encoding: utf-8
require 'digest/md5'

module Backup
  module Syncer
    module Cloud
      class LocalFile
        attr_reader :path, :md5

        class << self
          include Utilities::Helpers

          # Returns a Hash of LocalFile objects for each file within +dir+.
          # Hash keys are the file's path relative to +dir+.
          def find(dir, exclude_patterns = [])
            exclude_patterns = [exclude_patterns] if exclude_patterns.class == String
            dir = File.expand_path(dir)
            hash = {}
            find_md5(dir, exclude_patterns).each do |path, md5|
              file = new(path, md5)
              hash[path.sub(dir + '/', '')] = file if file
            end
            hash
          end

          # Return a new LocalFile object if it's valid.
          # Otherwise, log a warning and return nil.
          def new(*args)
            file = super
            if file.invalid?
              Logger.warn("\s\s[skipping] #{ file.path }\n" +
                          "\s\sPath Contains Invalid UTF-8 byte sequences")
              file = nil
            end
            file
          end

          private

          # Returns an Array of file paths and their md5 hashes.
          def find_md5(dir, exclude_patterns = [])
            exclude_patterns = [exclude_patterns] if exclude_patterns.class == String
            Dir.glob(File.join(dir, "**", "*")).reject do |f|
              File.directory?(f) || exclude_patterns.detect { |p| File.fnmatch?(p, f) }
            end.map do |f|
              [f, Digest::MD5.file(f).hexdigest]
            end
          end
        end

        # If +path+ contains invalid UTF-8, it will be sanitized
        # and the LocalFile object will be flagged as invalid.
        # This is done so @file.path may be logged.
        def initialize(path, md5)
          @path = sanitize(path)
          @md5 = md5
        end

        def invalid?
          !!@invalid
        end

        private

        def sanitize(str)
          str.each_char.map do |char|
            begin
              char.unpack('U')
              char
            rescue
              @invalid = true
              "\xEF\xBF\xBD" # => "\uFFFD"
            end
          end.join
        end

      end
    end
  end
end
