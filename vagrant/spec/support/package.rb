# encoding: utf-8

module BackupSpec
  class Package
    include Backup::Utilities::Helpers
    extend Forwardable
    def_delegators :@tarfile, :exist?, :manifest, :contents, :[]

    # Number of files that made up the final package.
    # If the Splitter was used, this will the number of 'chunks' created.
    # Otherwise, it will be 1 (or 0 if exist? is false)
    attr_reader :filecount

    # Type of encryption used.
    # Returns :gpg, :openssl or nil
    attr_reader :encryption

    def initialize(trigger)
      @files = Dir[File.join(LOCAL_STORAGE_PATH, trigger, '**', '*.tar*')]
      @filecount = @files.count

      path = unsplit
      path = decrypt(path)
      @tarfile = TarFile.new(path)
    end

    private

    def unsplit
      return @files.first unless filecount > 1

      base_dir = File.dirname(@files.first)
      orig_ext = File.extname(@files.first)
      base_ext = orig_ext.split('-').first
      outfile = File.basename(@files.first).sub(/#{ orig_ext }$/, base_ext)
      Dir.chdir(base_dir) do
        %x[#{ utility(:cat) } #{ outfile }-* > #{ outfile }]
      end
      File.join(base_dir, outfile)
    end

    def decrypt(path)
      return path unless encrypted?(path)

      # TODO: decrypt and return path
    end

    def encrypted?(path)
      path.to_s =~ /([.]gpg|[.]enc)$/
      @encryption =
          case $1
          when '.gpg' then :gpg
          when '.enc' then :openssl
          else; false
          end
    end
  end
end
