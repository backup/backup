class CreateBackupTables < ActiveRecord::Migration
  def self.up
    create_table :backup do |t|
      t.string :storage
      t.string :trigger
      t.string :adapter
      t.string :filename
      t.string :path
      t.string :bucket
      t.timestamps          
    end
  end

  def self.down
    drop_table :backup
  end
end