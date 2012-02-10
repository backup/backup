# encoding: utf-8

module Backup
  module Packager
    class << self
      include Backup::CLI::Helpers

      ##
      # Build the final package for the backup model.
      def package!(model)
        @package   = model.package
        @encryptor = model.encryptor
        @splitter  = model.splitter

        Logger.message "Packaging the backup files..."
        procedure.call
        Logger.message "Packaging Complete!"
      end

      private

      ##
      # Builds a chain of nested Procs which assemble and execute
      # the final command to package the backup.
      # This is done so that the Encryptor and Splitter have the ability
      # to perform actions before and after the final command is executed.
      # No Encryptors currently utilize this, however the Splitter does.
      def procedure
        stack = []

        ##
        # Initial `tar` command to package the temporary backup folder.
        # The command's output will then be either piped to the Encryptor
        # or the Splitter (if no Encryptor), or redirected into the final
        # output file if neither are configured.
        @package_command = "#{ utility(:tar) } -cf - " +
            "-C '#{ Config.tmp_path }' '#{ @package.trigger }'"

        ##
        # If an Encryptor was configured, it will be called first
        # to amend the command to be piped through the encryption utility.
        # It's output will then be either piped into a Splitter, or sent
        # directly to the final output file.
        if @encryptor
          stack << lambda do
            @encryptor.encrypt_with do |command, ext|
              @package_command << " | #{command}"
              @package.extension << ext
              stack.shift.call
            end
          end
        end

        ##
        # If a Splitter was configured, the command will be piped through
        # the `split` command. Once the Proc executing the final command
        # has completed and returns back to the Splitter, it will check the
        # final output files to determine if the backup was indeed split.
        # If so, it will set the package's chunk_suffixes. If not, it will
        # remove the '-aa' suffix from the only file created by `split`.
        #
        # If no Splitter was configured, the command output will be
        # redirected directly into the final output file.
        if @splitter
          stack << lambda do
            @splitter.split_with do |command|
              @package_command << " | #{command}"
              stack.shift.call
            end
          end
        else
          stack << lambda do
            outfile = File.join(Config.tmp_path, @package.basename)
            @package_command << " > #{ outfile }"
            stack.shift.call
          end
        end

        ##
        # Last Proc to be called runs the command the procedure built.
        # Once complete, the call stack will unwind back through the
        # preceeding Procs in the stack (if any)
        stack << lambda { run(@package_command) }

        stack.shift
      end

    end
  end
end
