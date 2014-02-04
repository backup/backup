require 'active_record'

namespace :db do
  desc 'Rebuild PostgreSQL Test Databases'
  task :postgresql do
    begin
      puts "\n=> Preparing PostgreSQL..."
      PostgreSQLTask.drop_all
      PostgreSQLTask.create_all
    rescue Exception => err
      $stderr.puts "#{ err.class }: #{ err.message }"
      $stderr.puts err.backtrace
    end
  end
end

module PostgreSQLTask
  extend ActiveSupport::Inflector

  class << self
    DATABASES = {
      backup_test_01: { # db_name
        ones: 100,      # table_name, record_count
        twos: 200,
        threes: 400
      },
      backup_test_02: {
        ones: 125,
        twos: 225,
        threes: 425
      }
    }
    CONFIG = {
      adapter:  'postgresql',
      encoding: 'utf8'
    }

    def drop_all
      puts 'Dropping Databases...'
      connection = connect_to(nil)
      DATABASES.keys.each do |db_name|
        connection.drop_database db_name
      end
    end

    def create_all
      connection = connect_to(nil)
      DATABASES.each do |db_name, tables|
        puts "Creating Database '#{ db_name }'..."
        connection.create_database db_name, CONFIG
        connection = connect_to(db_name)
        tables.each do |table_name, record_count|
          ActiveRecord::Schema.define do
            create_table table_name do |t|
              t.integer :number
            end
          end

          name = classify(table_name)
          klass = const_defined?(name) ? const_get(name) :
              const_set(name, Class.new(ActiveRecord::Base))
          record_count.times do |n|
            klass.create(number: n)
          end
        end
      end
    end

    private

    def connect_to(db_name)
      config = db_name ? CONFIG.merge(database: db_name.to_s) :
          CONFIG.merge(database: 'postgres', schema_search_path: 'public')
      ActiveRecord::Base.establish_connection config
      ActiveRecord::Base.connection
    end
  end
end
