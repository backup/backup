module Backup
  module Storage
    module Cycler
      class Error < Backup::Error; end

      private

      # Adds the current package being stored to the YAML cycle data file
      # and will remove any old package file(s) when the storage limit
      # set by #keep is exceeded.
      def cycle!
        Logger.info "Cycling Started..."

        packages = yaml_load.unshift(package)
        cycled_packages = []

        if keep.is_a?(Date) || keep.is_a?(Time)
          cycled_packages = packages.select do |p|
            p.time_as_object < keep.to_time
          end
        else
          excess = packages.count - keep.to_i
          cycled_packages = packages.last(excess) if excess > 0
        end

        saved_packages = packages - cycled_packages
        cycled_packages.each { |package| delete_package package }

        yaml_save(saved_packages)
      end

      def delete_package(package)
        remove!(package) unless package.no_cycle
      rescue => err
        Logger.warn Error.wrap(err, <<-EOS)
            There was a problem removing the following package:
            Trigger: #{package.trigger} :: Dated: #{package.time}
            Package included the following #{package.filenames.count} file(s):
            #{package.filenames.join("\n")}
          EOS
      end

      # Returns path to the YAML data file.
      def yaml_file
        @yaml_file ||= begin
          filename = self.class.to_s.split("::").last
          filename << "-#{storage_id}" if storage_id
          File.join(Config.data_path, package.trigger, "#{filename}.yml")
        end
      end

      # Returns stored Package objects, sorted by #time descending (oldest last).
      def yaml_load
        loaded =
          if File.exist?(yaml_file) && !File.zero?(yaml_file)
            if YAML.respond_to?(:safe_load_file)
              YAML.safe_load_file(yaml_file, permitted_classes: [Backup::Package])
            else
              YAML.load_file(yaml_file)
            end
          else
            []
          end

        loaded.sort_by!(&:time).reverse!
      end

      # Stores the given package objects to the YAML data file.
      def yaml_save(packages)
        FileUtils.mkdir_p(File.dirname(yaml_file))
        File.open(yaml_file, "w") do |file|
          file.write(packages.to_yaml)
        end
      end
    end
  end
end
