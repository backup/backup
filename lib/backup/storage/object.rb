# encoding: utf-8

module Backup
  module Storage
    class Object

      ##
      # Holds the type attribute
      attr_accessor :storage_file

      ##
      # Instantiates a new Backup::Storage::Object and stores the
      # full path to the storage file (yaml) in the @storage_file attribute
      def initialize(type, storage_id)
        suffix = storage_id.to_s.strip.gsub(/[\W\s]/, '_')
        filename = suffix.empty? ? type : "#{type}-#{suffix}"
        @storage_file = File.join(DATA_PATH, TRIGGER, "#{filename}.yml")
      end

      ##
      # Tries to load an existing YAML file and returns an
      # array of storage objects. If no file exists, an empty
      # array gets returned
      #
      # If a file is loaded it'll sort the array of objects by @time
      # descending. The newest backup storage object comes in Backup::Storage::Object.load[0]
      # and the oldest in Backup::Storage::Object.load[-1]
      def load
        objects = []
        if File.exist?(storage_file) and not File.zero?(storage_file)
          objects = YAML.load_file(storage_file).sort { |a,b| b.time <=> a.time }
          check(objects)
        end
        objects
      end

      ##
      # Takes the provided objects and converts it to YAML format.
      # The YAML data gets written to the storage file
      def write(objects)
        File.open(storage_file, 'w') do |file|
          file.write(objects.to_yaml)
        end
      end

      private

      def check(objects)
        if objects.any? {|object| object.instance_variable_defined?(:@remote_file) }
          Backup::Logger.warn "Backup cycling changed in version 3.0.20 and is not backwards compatible with previous versions."
          Backup::Logger.warn "Visit: https://github.com/meskyanichi/backup/wiki/Splitter for more information"
        end
      end

    end
  end
end
