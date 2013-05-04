# encoding: utf-8

module Backup
  class Splitter
    include Backup::Utilities::Helpers

    attr_reader :package, :chunk_size

    def initialize(model, chunk_size)
      @package = model.package
      @chunk_size = chunk_size
    end

    ##
    # This is called as part of the procedure used to build the final
    # backup package file(s). It yields it's portion of the command line
    # for this procedure, which will split the data being piped into it
    # into multiple files, based on the @chunk_size.
    # Once the packaging procedure is complete, it will return and
    # @package.chunk_suffixes will be set based on the resulting files.
    def split_with
      Logger.info "Splitter configured with a chunk size of #{ chunk_size }MB."
      yield split_command
      after_packaging
    end

    private

    ##
    # The `split` command reads from $stdin and will store it's output in
    # multiple files, based on the @chunk_size. The files will be
    # written using the given `prefix`, which is the full path to the
    # final @package.basename, plus a '-' separator. This `prefix` will then
    # be suffixed using 'aa', 'ab', and so on... for each file.
    def split_command
      "#{ utility(:split) } -b #{ chunk_size }m - " +
          "'#{ File.join(Config.tmp_path, package.basename + '-') }'"
    end

    ##
    # Finds the resulting files from the packaging procedure
    # and stores an Array of suffixes used in @package.chunk_suffixes.
    # If the @chunk_size was never reached and only one file
    # was written, that file will be suffixed with '-aa'.
    # In which case, it will simply remove the suffix from the filename.
    def after_packaging
      suffixes = chunk_suffixes
      if suffixes == ['aa']
        FileUtils.mv(
          File.join(Config.tmp_path, package.basename + '-aa'),
          File.join(Config.tmp_path, package.basename)
        )
      else
        package.chunk_suffixes = suffixes
      end
    end

    ##
    # Returns an array of suffixes for each chunk, in alphabetical order.
    # For example: [aa, ab, ac, ad, ae]
    def chunk_suffixes
      chunks.map {|chunk| File.extname(chunk).split('-').last }.sort
    end

    ##
    # Returns an array of full paths to the backup chunks.
    # Chunks are sorted in alphabetical order.
    def chunks
      Dir[File.join(Config.tmp_path, package.basename + '-*')].sort
    end

  end
end
