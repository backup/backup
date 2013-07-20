# encoding: utf-8

module Backup
  module Packager
    class Error < Backup::Error; end

    class << self
      include Backup::Utilities::Helpers

      ##
      # Build the final package for the backup model.
      def package!(model)
        @package   = model.package
        @encryptor = model.encryptor
        @splitter  = model.splitter
        @pipeline  = Pipeline.new

        Logger.info "Packaging the backup files..."
        procedure.call

        if @pipeline.success?
          Logger.info "Packaging Complete!"
        else
          raise Error, "Failed to Create Backup Package\n" +
              @pipeline.error_messages
        end
      end

      private

      ##
      # Builds a chain of nested Procs which adds each command to a Pipeline
      # needed to package the final command to package the backup.
      # This is done so that the Encryptor and Splitter have the ability
      # to perform actions before and after the final command is executed.
      # No Encryptors currently utilize this, however the Splitter does.
      def procedure
        stack = []

        ##
        # Initial `tar` command to package the temporary backup folder.
        # The command's output will then be either piped to the Encryptor
        # or the Splitter (if no Encryptor), or through `cat` into the final
        # output file if neither are configured.
        @pipeline << "#{ utility(:tar) } -cf - " +
            "-C '#{ Config.tmp_path }' '#{ @package.trigger }'"

        ##
        # If an Encryptor was configured, it will be called first
        # to add the encryption utility command to be piped through,
        # and amend the final package extension.
        # It's output will then be either piped into a Splitter,
        # or through `cat` into the final output file.
        if @encryptor
          stack << lambda do
            @encryptor.encrypt_with do |command, ext|
              @pipeline << command
              @package.extension << ext
              stack.shift.call
            end
          end
        end

        ##
        # If a Splitter was configured, the `split` utility command will be
        # added to the Pipeline to split the final output into multiple files.
        # Once the Proc executing the Pipeline has completed and returns back
        # to the Splitter, it will check the final output files to determine
        # if the backup was indeed split.
        # If so, it will set the package's chunk_suffixes. If not, it will
        # remove the '-aa' suffix from the only file created by `split`.
        #
        # If no Splitter was configured, the final file output will be
        # piped through `cat` into the final output file.
        if @splitter
          stack << lambda do
            @splitter.split_with do |command|
              @pipeline << command
              stack.shift.call
            end
          end
        else
          stack << lambda do
            outfile = File.join(Config.tmp_path, @package.basename)
            @pipeline << "#{ utility(:cat) } > #{ outfile }"
            stack.shift.call
          end
        end

        ##
        # Last Proc to be called runs the Pipeline the procedure built.
        # Once complete, the call stack will unwind back through the
        # preceeding Procs in the stack (if any)
        stack << lambda { @pipeline.run }

        stack.shift
      end

    end
  end
end
