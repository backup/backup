require 'backup'

namespace :backup do
  namespace :s3 do
    task :mysql do
      Backup::Mysql.new({
        :mysql => {
          :user     => "root",
          :password => "",
          :database => "foobar"
        },
        
        :use => :s3,
        :s3 => {
          :access_key_id      => 'AKIAIBSZJIDXPPY5COWQ',
          :secret_access_key  => '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',
          :bucket             => 'final-creation'
        }
      }).run
    end
    
    task :sqlite3 do
      Backup::Sqlite3.new({
        :file => 'development.sqlite3',
        
        :use => :s3,
        :s3 => {
          :access_key_id      => 'AKIAIBSZJIDXPPY5COWQ',
          :secret_access_key  => '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',
          :bucket             => 'final-creation'
        }
      }).run
    end
    
    task :assets do
      Backup::Assets.new({
        :path => "#{RAILS_ROOT}/public/assets",
        
        :use => :s3,
        :s3 => {
          :access_key_id      => 'AKIAIBSZJIDXPPY5COWQ',
          :secret_access_key  => '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',
          :bucket             => 'final-creation'
        }
      }).run
    end
  end
end