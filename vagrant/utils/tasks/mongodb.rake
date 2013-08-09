require 'mongo'

namespace :db do
  desc 'Rebuild MongoDB Test Databases'
  task :mongodb do
    puts "\n=> Preparing MongoDB..."
    MongoDBTask.mongod_start
    begin
      MongoDBTask.drop_all
      MongoDBTask.create_all
    rescue Exception => err
      $stderr.puts "#{ err.class }: #{ err.message }"
      $stderr.puts err.backtrace
    end
  end
end

module MongoDBTask
  class << self

    DATABASES = {
      backup_test_01: { # db_name
        ones: 100,      # collection_name, record_count
        twos: 200,
        threes: 400
      },
      backup_test_02: {
        ones: 125,
        twos: 225,
        threes: 425
      }
    }

    def mongod_running?
      %x[systemctl status mongod.service >/dev/null 2>&1; echo $?].chomp == '0'
    end

    # in case VM fails to exit cleanly
    def mongod_start
      return if mongod_running?

      puts 'Starting mongod.service...'
      %x[sudo rm -f /var/lib/mongodb/mongod.lock]
      %x[sudo systemctl start mongod.service]
      ready = false
      10.times do
        ready = mongod_running?
        break if ready
        sleep 1
      end
      abort 'Failed to start mongod.service' unless ready
    end

    def drop_all
      puts 'Dropping Databases...'
      DATABASES.keys.each do |db_name|
        mongo_client.drop_database db_name.to_s
      end
    end

    def create_all
      DATABASES.each do |db_name, collections|
        puts "Creating Database '#{ db_name }'..."
        db = mongo_client.db db_name.to_s

        collections.each do |collection_name, record_count|
          coll = db.collection collection_name.to_s
          record_count.times {|n| coll.insert number: n }
        end
      end
    end

    private

    def mongo_client
      @mongo_client ||= Mongo::MongoClient.new
    end
  end
end
