# encoding: utf-8

module Backup
  module Cleaner
    class Error < Backup::Error; end

    class << self

      ##
      # Logs warnings if any temporary files still exist
      # from the last time this model/trigger was run,
      # then removes the files.
      def prepare(model)
        messages = []

        packaging_folder = File.join(Config.tmp_path, model.trigger)
        if File.exist?(packaging_folder)
          messages << <<-EOS
            The temporary packaging folder still exists!
            '#{ packaging_folder }'
            It will now be removed.
          EOS
          FileUtils.rm_rf(packaging_folder)
        end

        package_files = package_files_for(model.trigger)
        unless package_files.empty?
          # the chances of the packaging folder AND
          # the package files existing are practically nil
          messages << ('-' * 74) unless messages.empty?

          messages << <<-EOS
            The temporary backup folder '#{ Config.tmp_path }'
            appears to contain the package files from the previous backup!
            #{ package_files.join("\n") }
            These files will now be removed.
          EOS
          package_files.each {|file| FileUtils.rm_f(file) }
        end

        unless messages.empty?
          Logger.warn Error.new(<<-EOS)
            Cleanup Warning
            #{ messages.join("\n") }
            Please check the log for messages and/or your notifications
            concerning this backup: '#{ model.label } (#{ model.trigger })'
            The temporary files which had to be removed should not have existed.
          EOS
        end
      end

      ##
      # Remove the temporary folder used during packaging
      def remove_packaging(model)
        Logger.info "Cleaning up the temporary files..."
        FileUtils.rm_rf(File.join(Config.tmp_path, model.trigger))
      end

      ##
      # Remove the final package files from tmp_path
      # Note: 'force' is used, since a Local Storage may *move* these files.
      def remove_package(package)
        Logger.info "Cleaning up the package files..."
        package.filenames.each do |file|
          FileUtils.rm_f(File.join(Config.tmp_path, file))
        end
      end

      ##
      # Logs warnings if any temporary files still exist
      # when errors occur during the backup
      def warnings(model)
        messages = []

        packaging_folder = File.join(Config.tmp_path, model.trigger)
        if File.exist?(packaging_folder)
          messages << <<-EOS
            The temporary packaging folder still exists!
            '#{ packaging_folder }'
            This folder may contain completed Archives and/or Database backups.
          EOS
        end

        package_files = package_files_for(model.trigger)
        unless package_files.empty?
          # the chances of the packaging folder AND
          # the package files existing are practically nil
          messages << ('-' * 74) unless messages.empty?

          messages << <<-EOS
            The temporary backup folder '#{ Config.tmp_path }'
            appears to contain the backup files which were to be stored:
            #{ package_files.join("\n") }
          EOS
        end

        unless messages.empty?
          Logger.warn Error.new(<<-EOS)
            Cleanup Warning
            #{ messages.join("\n") }
            Make sure you check these files before the next scheduled backup for
            '#{ model.label } (#{ model.trigger })'
            These files will be removed at that time!
          EOS
        end
      end

      private

      def package_files_for(trigger)
        Dir[File.join(Config.tmp_path,"#{ trigger }.tar{,[.-]*}")]
      end

    end
  end
end
