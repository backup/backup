# encoding: utf-8

module Backup
  module CLI
    module Helpers
      UTILITY = {}

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
      # Returns the full path to the specified utility.
      # Raises an error if utility can not be found in the system's $PATH
      def utility(name)
        path = UTILITY[name] || %x[which #{name} 2>/dev/null].chomp
        if path.empty?
          raise Errors::CLI::UtilityNotFoundError, <<-EOS
            Path to '#{ name }' could not be found.
            Make sure the specified utility is installed
            and available in your system's $PATH.
            If this is a database utility, you may need to specify the full path
            using the Database's '<utility_name>_utility' configuration setting.
          EOS
        end
        UTILITY[name] = path
      end

      ##
      # Returns the name of the command name from the given command line
      def command_name(command)
        i = command =~ /\s/
        command = command.slice(0, i) if i
        command.split('/')[-1]
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
