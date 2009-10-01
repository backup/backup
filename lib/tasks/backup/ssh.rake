require 'backup'

namespace :backup do
  namespace :ssh do
    task :mysql do
      Backup::Mysql.new({
        :mysql => {
          :user     => "root",
          :password => "",
          :database => "foobar"
        },
        
        :use => :ssh,
        :ssh => {
          :user => "root",
          :ip   => "final-creation.com",
          :path => "/home/michael"
        }
      }).run
    end
    
    task :sqlite3 do
      Backup::Sqlite3.new({
        :file => 'development.sqlite3',
        
        :use => :ssh,
        :ssh => {
          :user => "root",
          :ip   => "final-creation.com",
          :path => "/home/michael"
        }
      }).run
    end
    
    task :assets do
      Backup::Assets.new({
        :path => "#{RAILS_ROOT}/public/assets",
        
        :use => :ssh,
        :ssh => {
          :user => "root",
          :ip   => "final-creation.com",
          :path => "/home/michael"
        }
      }).run
    end
  end
end