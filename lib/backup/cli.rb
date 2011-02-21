# encoding: utf-8

module Backup
  module CLI

    ##
    # Wrapper method for %x[] to run CL commands
    # through a ruby method. This helps with test coverage and
    # improves readability
    def run(command)
      %x[#{command}]
    end

    ##
    # Wrapper method for FileUtils.mkdir_p to create directories
    # through a ruby method. This helps with test coverage and
    # improves readability
    def mkdir(path)
      FileUtils.mkdir_p(path)
    end

    ##
    # Wrapper for the FileUtils.rm_rf to remove files and folders
    # through a ruby method. This helps with test coverage and
    # improves readability
    def rm(path)
      FileUtils.rm_rf(path)
    end

    ##
    # Tries to find the full path of the specified utility. If the full
    # path is found, it'll return that. Otherwise it'll just return the
    # name of the utility.
    def utility(name)
      if path = %x[which #{name}].chomp and not path.empty?
        return path
      end
      name
    end

  end
end
