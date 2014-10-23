# encoding: utf-8

module Backup
  module Storage
    module Cycler
      class Error < Backup::Error; end

      private

      # Adds the current package being stored to the YAML cycle data file
      # and will remove any old package file(s) when the storage limit
      # set by #keep is exceeded.
      def cycle!
        Logger.info 'Cycling Started...'

        packages = yaml_load.unshift(package)
        excess = packages.count - keep.to_i
        excess = 0 if keep.to_i == 0
        
        if excess > 0
          packages.pop(excess).each do |pkg|
            begin
              remove!(pkg) unless pkg.no_cycle
            rescue => err
              Logger.warn Error.wrap(err, <<-EOS)
                There was a problem removing the following package:
                Trigger: #{pkg.trigger} :: Dated: #{pkg.time}
                Package included the following #{ pkg.filenames.count } file(s):
                #{ pkg.filenames.join("\n") }
              EOS
            end
          end
        end

        yaml_save(packages)
      end

      # Returns path to the YAML data file.
      def yaml_file
        @yaml_file ||= begin
          filename = self.class.to_s.split('::').last
          filename << "-#{ storage_id }" if storage_id
          File.join(Config.data_path, package.trigger, "#{ filename }.yml")
        end
      end

      # Returns stored Package objects, sorted by #time descending (oldest last).
      def yaml_load
        if File.exist?(yaml_file) && !File.zero?(yaml_file)
          YAML.load_file(yaml_file).sort_by!(&:time).reverse!
        else
          []
        end
      end

      # Stores the given package objects to the YAML data file.
      def yaml_save(packages)
        FileUtils.mkdir_p(File.dirname(yaml_file))
        File.open(yaml_file, 'w') do |file|
          file.write(packages.to_yaml)
        end
      end

    end
  end
end
