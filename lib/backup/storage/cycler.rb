# encoding: utf-8

module Backup
  module Storage
    module Cycler
      class Error < Backup::Error; end

      class << self

        ##
        # Adds the given +package+ to the YAML storage file corresponding
        # to the given +storage+ and Package#trigger (Model#trigger).
        # Then, calls the +storage+ to remove the files for any older
        # packages that were removed from the YAML storage file.
        def cycle!(storage)
          @storage = storage
          @package = storage.package
          @storage_file = storage_file

          update_storage_file!
          remove_packages!
        end

        private

        ##
        # Updates the YAML data file according to the #keep setting
        # for the storage and sets the @packages_to_remove
        def update_storage_file!
          packages = yaml_load.unshift(@package)
          excess = packages.count - @storage.keep.to_i
          @packages_to_remove = (excess > 0) ? packages.pop(excess) : []
          yaml_save(packages)
        end

        ##
        # Calls the @storage to remove any old packages
        # which were cycled out of the storage file.
        def remove_packages!
          @packages_to_remove.each do |pkg|
            begin
              @storage.send(:remove!, pkg) unless pkg.no_cycle
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

        ##
        # Return full path to the YAML data file,
        # based on the current values of @storage and @package
        def storage_file
          filename = @storage.class.to_s.split('::').last
          filename << "-#{ @storage.storage_id }" if @storage.storage_id
          File.join(Config.data_path, @package.trigger, "#{ filename }.yml")
        end

        ##
        # Load Package objects from YAML file.
        # Returns an Array, sorted by @time descending.
        # i.e. most recent is objects[0]
        def yaml_load
          packages = []
          if File.exist?(@storage_file) && !File.zero?(@storage_file)
            packages = check_upgrade(
              YAML.load_file(@storage_file).sort do |a, b|
                b.instance_variable_get(:@time) <=> a.instance_variable_get(:@time)
              end
            )
          end
          packages
        end

        ##
        # Store the given package objects to the YAML data file.
        def yaml_save(packages)
          FileUtils.mkdir_p(File.dirname(@storage_file))
          File.open(@storage_file, 'w') do |file|
            file.write(packages.to_yaml)
          end
        end

        ##
        # Upgrade the objects loaded from the YAML file, if needed.
        def check_upgrade(objects)
          if objects.any? {|obj| obj.class.to_s =~ /Backup::Storage/ }
            # Version <= 3.0.20
            model = @storage.instance_variable_get(:@model)
            v3_0_20 = objects.any? {|obj| obj.instance_variable_defined?(:@version) }
            objects.map! do |obj|
              if v3_0_20 # Version == 3.0.20
                filename = obj.instance_variable_get(:@filename)[20..-1]
                chunk_suffixes = obj.instance_variable_get(:@chunk_suffixes)
              else # Version <= 3.0.19
                filename = obj.instance_variable_get(:@remote_file)[20..-1]
                chunk_suffixes = []
              end
              time = obj.instance_variable_get(:@time)
              extension = filename.match(/\.(tar.*)$/)[1]

              package = Backup::Package.new(model)
              package.instance_variable_set(:@time, time)
              package.extension = extension
              package.chunk_suffixes = chunk_suffixes

              package
            end
          end
          objects
        end

      end
    end
  end
end
