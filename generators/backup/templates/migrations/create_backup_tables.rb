class CreateBackupTables < ActiveRecord::Migration
  def self.up
    create_table :backup_s3 do |t|
      t.string :trigger
      t.string :adapter
      t.string :filename
      t.string :bucket
      t.timestamps
    end
    
    create_table :backup_scp do |t|
      t.string :trigger
      t.string :adapter
      t.string :filename
      t.string :path
      t.timestamps          
    end
  end

  def self.down
    drop_table :backup_s3
    drop_table :backup_scp
  end
end