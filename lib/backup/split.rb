module Backup
  class Split

    # A string containing a size specifier that the split(1) utility
    # understands. e.g. "1m", or "2g"
    attr_accessor :size

    # The file we should split
    attr_accessor :source_file


    def initialize(size)
      @size = size.to_s.downcase
      @source_file = Backup::Model.current.file
      begin
        validate_size
        expand_size
      rescue ArgumentError => e
        raise e
      end
    end

    def validate_size
      unless /^[0-9]+[k|m|g|t|p]?/.match(@size)
        raise ArgumentError.new "A size for splitting needs to be of the form [0-9]+[k|m|g|t|p]?"
      end
    end

    def expand_size
      # Select out the numbers in the size
      base = @size.split('').select{ |char| (0..9).to_a.map{|n| n.to_s}.include?(char) }.join.to_i
      multiplier = case(@size[-1].chr)
                   when 'P', 'p'
                     1024 ** 5
                   when 'T', 't'
                     1024 ** 4
                   when 'G', 'g'
                     1024 ** 3
                   when 'M', 'm'
                     1024 ** 2
                   when 'K', 'k'
                     1024
                   end
      @size = base*multiplier
    end

    def letters_needed
      file_size = File.stat(source_file)
      chunks = (file_size.to_f / @size.to_f).ceil

      letters_needed = Math.log(chunks) / Math.log(26) # Log base 26 because of the number of letters in the alphabet.
    end

    def perform!
      # Actually split the file.
      # e.g.: 2011.07.06.23.59.59.trigger.tar.bz2 -> 2011.07.06.23.59.59.trigger.tar.bz2-xaa, 2011.07.06.23.59.59.trigger.tar.bz2-xab, etc.
      run("#{ utility(split) } -a #{ letters_needed } -b #{ @size } #{ source_file } #{ source_file } #{ source_file }-")
      Backup::Model.current.files = Dir.glob(source_file+"-*")
    end

  end
end
