# Opens and Reads the Backup YAML File from the RAILS_ROOT/config/backup path
# Replaces all the :rails_root tokens with the actual RAILS_ROOT path
# Returns the content of the file in YAML format
def read_backup_yaml_file(config_file)  
  YAML.load File.open(File.join(RAILS_ROOT, 'config', 'backup', config_file), 'r').read.gsub(/:rails_root/, RAILS_ROOT)
end

namespace :backup do

  task :s3_config => :environment do
    @config   = read_backup_yaml_file('s3.yml')
    @adapters = ['mysql', 'sqlite3', 'assets', 'custom']
  end
  
  task :ssh_config => :environment do
    @config   = read_backup_yaml_file('ssh.yml')
    @adapters = ['mysql', 'sqlite3', 'assets', 'custom']
  end
  
end