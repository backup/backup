module Backup
  module CommandHelper
    def run(command, opts={})
      opts[:exit_on_failure] ||= false
      output = `#{command}`
      exit 1 if opts[:exit_on_failure] && !$?.success?
      output
    end
 
    def log(command)
      puts "Backup (#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}) => #{command}"
    end
  end
end
