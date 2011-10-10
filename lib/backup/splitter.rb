
# The splitter module helps backup storage implementations to split the archived files into
# chunks of configurable size. The storage implementations should call split! before transferring.
# Subsequently, they can then use local_chunks or remote_chunks to access the resulting chunks of
# archive file for actual transfer or removal. If splitting is not enabled, there will be just a single chunk.
module Backup
  module Splitter
    include Backup::CLI

    SUFFIX_SEPARATOR = "-"

    # Whether to split at all.
    attr_accessor :split_archive_file

    # Size of the chunks. Must be specified if splitting is enabled.
    attr_accessor :archive_file_chunk_size

    # In here, it is stored in how many chunks the archive file was split.
    attr_accessor :number_of_archive_chunks

    def split!
      return do_no_split unless split_archive_file
      if check_config
        set_number_of_chunks
        do_split
      else
        log_bad_config
      end
    end

    def local_chunks
      return [absolute_path_to_local_file] unless split_archive_file
      local_files = []
      for i in 0..number_of_archive_chunks-1
        local_files << "#{absolute_path_to_local_file + SUFFIX_SEPARATOR}#{"%02d" % i}"
      end
      local_files
    end

    def remote_chunks
      return [absolute_path_to_remote_file] unless split_archive_file
      remote_files = []
      for i in 0..number_of_archive_chunks-1
        remote_files << "#{absolute_path_to_remote_file + SUFFIX_SEPARATOR }#{"%02d" % i}"
      end
      remote_files
    end

    def local_to_remote_chunks
      Hash[local_chunks.zip(remote_chunks)]
    end

    private

    def do_no_split
      self.number_of_archive_chunks = 1
    end

    def do_split
      run("split -b #{archive_file_chunk_size}MB -d #{absolute_path_to_local_file} #{absolute_path_to_local_file + SUFFIX_SEPARATOR}")
      local_chunks
    end

    def set_number_of_chunks
      local_file_size = File.size?(absolute_path_to_local_file)
      count = local_file_size / (mb2byte(archive_file_chunk_size))
      count +=1 unless (local_file_size % (mb2byte(archive_file_chunk_size)) == 0)
      self.number_of_archive_chunks = count
    end

    def log_bad_config
      Logger.error("Configuration for file splitting invalid: ")
      Logger.error("split_archive_file is set to #{split_archive_file}. It should be either true or false.")
      Logger.error("archive_file_chunk_size is set to #{archive_file_chunk_size}. It should be the size of a chunk in MB.")
    end

    def check_config
      return false if archive_file_chunk_size.nil?
      return false unless archive_file_chunk_size.is_a? Integer
      return false unless archive_file_chunk_size > 0
      true
    end

    def mb2byte(mb)
      mb * 1000 * 1000
    end

    def absolute_path_to_local_file
      File.join(local_path, local_file)
    end

    def absolute_path_to_remote_file
      File.join(remote_path, remote_file)
    end

  end
end