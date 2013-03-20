require 'redis'

namespace :db do
  desc 'Rebuild Redis Test Databases'
  task :redis do
    begin
      puts "\n=> Preparing Redis..."
      RedisTask.drop_all
      RedisTask.create_all
    rescue Exception => err
      $stderr.puts "#{ err.class }: #{ err.message }"
      $stderr.puts err.backtrace
    end
  end
end

module RedisTask
  class << self

    # Database::Redis doesn't currently support specifying
    # a database number to connect to.
    #
    # DATABASES = {
    #   # db_number, record_count
    #   0 => 100,
    #   1 => 200
    # }

    def drop_all
      puts 'Dropping Database...'
      redis_client.flushall
    end

    def create_all
      puts "Creating Database..."
      500.times {|n| redis_client.set "key_#{ n }", n }
      redis_client.save
    end

    private

    def redis_client
      @redis_client ||= Redis.new
    end
  end
end
