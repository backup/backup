module Backup
  module CommandHelper
    def run(command)
      Kernel.system command
    end
 
    def log(command)
      puts "Backup => #{command}"
    end
  end
end
