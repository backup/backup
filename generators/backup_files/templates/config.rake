def generate_yaml(config_file)
  File.open(File.join(RAILS_ROOT, 'config', 'backup', config_file), 'r') do |file|
    tmp_file = File.new(File.join(RAILS_ROOT, 'config', 'backup', 'tmp.yml'), 'w+')
    tmp_file.write(file.read.gsub(/:rails_root/, RAILS_ROOT))
    tmp_file.close
  end      
  yaml_file = YAML.load_file(File.join(RAILS_ROOT, 'config', 'backup', 'tmp.yml'))
  File.delete(File.join(RAILS_ROOT, 'config', 'backup', 'tmp.yml'))
  return yaml_file
end

namespace :backup do

  task :s3_config => :environment do
    @config = generate_yaml('s3.yml')
  end
  
  task :ssh_config => :environment do
    @config = generate_yaml('ssh.yml')
  end
  
end