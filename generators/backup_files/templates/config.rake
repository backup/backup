namespace :backup do

  task :s3_config => :environment do
    @config = YAML.load_file(File.join(RAILS_ROOT, 'config', 'backup', 's3.yml'))
    
    @config.each do |key, value|
      value.each do |k, v|
        if @config[key][k].is_a?(String)
          @config[key][k] = @config[key][k][v].gsub(/:rails_root/, RAILS_ROOT)
        end     
        if @config[key][k].is_a?(Array)
          @config[key][k].map! {|string| string.gsub(/:rails_root/, RAILS_ROOT)}
        end
      end
    end
  end
  
  task :ssh_config => :environment do
    @config = YAML.load_file(File.join(RAILS_ROOT, 'config', 'backup', 'ssh.yml'))
    
    @config.each do |key, value|
      value.each do |k, v|
        if @config[key][k].is_a?(String)
          @config[key][k] = @config[key][k][v].gsub(/:rails_root/, RAILS_ROOT)
        end     
        if @config[key][k].is_a?(Array)
          @config[key][k].map! {|string| string.gsub(/:rails_root/, RAILS_ROOT)}
        end
      end
    end
  end
  
end