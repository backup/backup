# encoding: utf-8
require 'digest/md5'

module Backup
  module Syncer
    module Cloud
      class LocalFile
        attr_reader :path
        attr_accessor :md5

        class << self

          # Returns a Hash of LocalFile objects for each file within +dir+,
          # except those matching any of the +excludes+.
          # Hash keys are the file's path relative to +dir+.
          def find(dir, excludes = [])
            dir = File.expand_path(dir)
            hash = {}
            find_md5(dir, excludes).each do |file|
              hash[file.path.sub(dir + '/', '')] = file
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
          def find_md5(dir, excludes)
            found = []
            (Dir.entries(dir) - %w{. ..}).map {|e| File.join(dir, e) }.each do |path|
              if File.directory?(path)
                unless exclude?(excludes, path)
                  found += find_md5(path, excludes)
                end
              elsif File.file?(path)
                if file = new(path)
                  unless exclude?(excludes, file.path)
                    file.md5 = Digest::MD5.file(file.path).hexdigest
                    found << file
                  end
                end
              end
            end
            found
          end

          # Returns true if +path+ matches any of the +excludes+.
          # Note this can not be called if +path+ includes invalid UTF-8.
          def exclude?(excludes, path)
            excludes.any? do |ex|
              if ex.is_a?(String)
                File.fnmatch?(ex, path)
              elsif ex.is_a?(Regexp)
                ex.match(path)
              end
            end
          end
        end

        # If +path+ contains invalid UTF-8, it will be sanitized
        # and the LocalFile object will be flagged as invalid.
        # This is done so @file.path may be logged.
        def initialize(path)
          @path = sanitize(path)
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
