module Backup
  class Encrypt
    
    attr_accessor :options
    
    def initialize(options = {})
      self.options = options
    end
    
    def run
      unencrypted_file  = File.join(options[:backup_path], options[:backup_file])
      encrypted_file    = File.join(options[:backup_path], options[:backup_file] + '.enc')
      %x{ openssl enc -des-cbc -in #{unencrypted_file} -out #{encrypted_file} -k #{options[:encrypt]} }
    end
    
  end  
end