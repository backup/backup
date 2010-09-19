module Backup
  module CommandHelper
    def run(command)
      Kernel.system command
    end
 
    def log(command)
      puts "Backup (#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}) => #{command}"
    end
  end
end
