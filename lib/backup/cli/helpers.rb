# encoding: utf-8

module Backup
  module CLI
    module Helpers

      ##
      # Runs a given command in an isolated (sub) process using POpen4.
      # The STDOUT, STDERR and the returned exit code of the utility will be stored in the process_data Hash.
      #
      # If a command returns an exit code other than 0, an exception will raise and the backup process will abort.
      # Some utilities return exit codes other than 0 which aren't an issue in Backup's context. If this is the case,
      # you can pass in an array of exit codes to ignore (whitelist), for example:
      #
      #   run("tar -cf /output.tar /some/folder", :ignore_exit_codes => [1])
      #
      # So if the `tar` utility returns in this case 1, Backup will consider it an acceptable return code.
      #
      # Note: Exit code 0 is always automatically added to the :ignore_exit_codes array, regardless of whether you specify an
      #       array to ignore or not.
      def run(command, options = {})
        command.gsub!(/^\s+/, "")

        process_data                     = Hash.new
        pid, stdin, stdout, stderr       = Open4::popen4(command)
        ignored, process_data[:status]   = Process::waitpid2(pid)
        process_data[:stdout]            = stdout.read
        process_data[:stderr]            = stderr.read
        process_data[:ignore_exit_codes] = ((options[:ignore_exit_codes] || Array.new) << 0).uniq

        raise_if_command_failed!(command_name(command), process_data)
        process_data[:stdout]
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

        if path = %x[which #{name} 2>/dev/null].chomp and not path.empty?
          return path
        end
        name
      end

      ##
      # Returns the name of the command
      def command_name(command)
        command.slice(0, command.index(/\s/)).split('/')[-1]
      end

      ##
      # Inspects the exit code returned from the POpen4 child process. If the exit code isn't listed
      # in the process_data[:ignore_exit_codes] array, an exception will be raised, aborting the backup process.
      #
      # Information regarding the error ( EXIT CODE and STDERR ) will be returned to the shell so the user can
      # investigate the issue.
      #
      # raises Backup::Errors::CLI::SystemCallError
      def raise_if_command_failed!(utility, process_data)
        unless process_data[:ignore_exit_codes].include?(process_data[:status].to_i)

          stderr = process_data[:stderr].empty? ?
              nil : "STDERR:\n#{process_data[:stderr]}\n"
          stdout = process_data[:stdout].empty? ?
              nil : "STDOUT:\n#{process_data[:stdout]}\n"

          raise Errors::CLI::SystemCallError, <<-EOS
            Failed to run #{utility} on #{RUBY_PLATFORM}
            The following information should help to determine the problem:
            Exit Code: #{process_data[:status]}
            #{stderr}#{stdout}
          EOS
        end
      end

    end
  end
end
