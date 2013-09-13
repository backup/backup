# encoding: utf-8

module Backup
  module Syncer
    module Cloud
      class LocalFile
        attr_reader :path, :md5

        class << self
          include Utilities::Helpers

          # Returns a Hash of LocalFile objects for each file within +dir+.
          # Hash keys are the file's path relative to +dir+.
          def find(dir)
            dir = File.expand_path(dir)
            hash = {}
            find_md5(dir).each do |path, md5|
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
          #
          # Lines output from `cmd` are formatted like:
          #   MD5(/dir/subdir/file)= 7eaabd1f53024270347800d0fdb34357
          # However, if +dir+ is empty, the following is returned:
          #   (stdin)= d41d8cd98f00b204e9800998ecf8427e
          # Which extracts as: ['in', 'd41d8cd98f00b204e9800998ecf8427e']
          # I'm not sure I can rely on the fact this doesn't begin with 'MD5',
          # so I'll reject entries with a path that doesn't start with +dir+.
          #
          # String#slice avoids `invalid byte sequence in UTF-8` errors
          # that String#split would raise.
          #
          # Utilities#run is not used here because this would produce too much
          # log output, and Pipeline does not support capturing output.
          def find_md5(dir)
            cmd = "#{ utility(:find) } -L '#{ dir }' -type f -print0 | " +
                  "#{ utility(:xargs) } -0 #{ utility(:openssl) } md5 2> /dev/null"
            %x[#{ cmd }].lines.map do |line|
              line.chomp!
              entry = [line.slice(4..-36), line.slice(-32..-1)]
              entry[0].to_s.start_with?(dir) ? entry : nil
            end.compact
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
