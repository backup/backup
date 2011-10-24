# encoding: utf-8

module Backup
  class Splitter
    include Backup::CLI

    ##
    # Separates the end of the file from the chunk extension name
    SUFFIX_SEPARATOR = "-"

    ##
    # Holds an instance of the current Backup model
    attr_accessor :model

    ##
    # Instantiates a new instance of Backup::Splitter and takes
    # a Backup model as an argument.
    # Also, (re)set the Backup::Model.chunk_suffixes to an empty array.
    def initialize(model)
      @model = model
      Backup::Model.chunk_suffixes = Array.new
    end

    ##
    # Splits the file in multiple chunks if necessary, and it's necessary
    # when the requested chunk size is smaller than the actual backup file
    def split!
      return unless model.chunk_size.is_a?(Integer)

      if File.size(model.file) > bytes_representation_of(model.chunk_size)
        Logger.message "Backup started splitting the packaged archive in to chunks of #{ model.chunk_size } megabytes."
        run("#{ utility("split") } -b #{ model.chunk_size }m '#{ model.file }' '#{ model.file + SUFFIX_SEPARATOR }'")
        Backup::Model.chunk_suffixes = chunk_suffixes
      end
    end

  private

    ##
    # Returns an array of suffixes for each chunk.
    # For example: [aa, ab, ac, ad, ae] - Chunk suffixes are sorted on alphabetical order
    def chunk_suffixes
      chunks.map do |chunk|
        File.extname(chunk).split("-").last
      end.sort
    end

    ##
    # Returns an array of full paths to the backup chunks.
    # Chunks aresorted on alphabetical order
    def chunks
      Dir["#{model.file}-*"].sort
    end

    ##
    # Converts the provided megabytes to a bytes representation
    def bytes_representation_of(megabytes)
      megabytes * 1024 * 1024
    end

  end
end
