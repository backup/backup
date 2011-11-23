# encoding: utf-8

module Backup
  module CLI
    ##
    # Wrapper method for %x[] to run CL commands
    # through a ruby method. This helps with test coverage and
    # improves readability.
    #
    # It'll first remove all prefixing slashes ( / ) by using .gsub(/^\s+/, '')
    # This allows for the EOS blocks to be indented without actually using any
    # prefixing spaces. This cleans up the implementation code.
    #
    # Every time the Backup::CLI#run method is invoked, it'll invoke
    # the Backup::CLI#raise_if_command_not_found method after running the
    # requested command on the OS.
    #
    # Backup::CLI#raise_if_command_not_found takes a single argument, the utility name.
    # the command.slice(0, command.index(/\s/)).split('/')[-1] line will extract only the utility
    # name (e.g. mongodump, pgdump, etc) from a command like "/usr/local/bin/mongodump <options>"
    # and pass that in to the Backup::CLI#raise_if_command_not_found
    def run(command)
      command.gsub!(/^\s+/, '')
      raise_if_command_not_found!(
        command_name(command)
      )

      pid, stdin, stdout, stderr = Open4::popen4(command)
      ignored, @status = Process::waitpid2(pid)
      @stdout = stdout.read
      @stderr = stderr.read

      raise_if_command_failed!(command_name(command), @status)
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
    # name of the utility. If the 'utility_path' is defined, it'll check
    # to see if it isn't an empty string, and if it isn't, it'll go ahead and
    # always use that path rather than auto-detecting it
    def utility(name)
      if respond_to?(:utility_path)
        if utility_path.is_a?(String) and not utility_path.empty?
          return utility_path
        end
      end

      if path = %x[which #{name}].chomp and not path.empty?
        return path
      end
      name
    end

    def command_name(command)
      command.slice(0, command.index(/\s/)).split('/')[-1]
    end

    ##
    # If the command that was previously run via this Ruby process returned
    # error code "32512", the invoked utility (e.g. mysqldump, pgdump, etc) could not be found.
    # If this is the case then this method will throw an exception, informing the user of this problem.
    #
    # Since this raises an exception, it'll stop the entire backup process, clean up the temp files
    # and notify the user via the built-in notifiers if these are set.
    def raise_if_command_not_found!(utility)
      if $?.to_i.eql?(32512)
        raise Exception::CommandNotFound , "Could not find the utility \"#{utility}\" on \"#{RUBY_PLATFORM}\".\n" +
                                           "If this is a database utility, try defining the 'utility_path' option in the configuration file.\n" +
                                           "See the Database Wiki for more information about the Utility Path option."
      end
    end

    ##
    # If the command that was previously run via this Ruby process returned
    # a non-zero error code, the invoked utility (e.g. mysqldump, pgdump, etc) failed to run.
    # If this is the case then this method will throw an exception, informing the user of this problem.
    #
    # Since this raises an exception, it'll stop the entire backup process, clean up the temp files
    # and notify the user via the built-in notifiers if these are set.
    def raise_if_command_failed!(utility, status)
      unless status.to_i.eql?(0)
        raise Exception::CommandFailed , "Failed to run \"#{utility}\" on \"#{RUBY_PLATFORM}\".\n" +
                                         "The status code returned was #{status}\n" +
                                         "STDOUT was:\n" +
                                         @stdout +
                                         "STDERR was:\n" +
                                         @stderr
      end
    end

  end
end
