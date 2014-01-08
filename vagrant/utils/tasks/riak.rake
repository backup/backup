require 'riak'

namespace :db do
  desc 'Rebuild Riak Test Databases'
  task :riak do
    puts "\n=> Preparing Riak..."
    RiakTask.recreate_node
    begin
      RiakTask.load_data
    rescue Exception => err
      $stderr.puts "#{ err.class }: #{ err.message }"
      $stderr.puts err.backtrace
    end
  end
end

module RiakTask
  class << self

    def recreate_node
      puts "-> Stopping Riak Service..."
      %x[sudo systemctl -q stop riak.service]

      puts "-> Removing Node Data..."
      %x[sudo rm -rf /var/lib/riak/{ring,bitcask,anti_entropy,kv_vnode}]

      puts "-> Starting Riak Service..."
      %x[sudo systemctl start riak.service]
      ready = false
      10.times do
        ready = %x[riak ping 2>/dev/null].chomp == 'pong'
        break if ready
        sleep 1
      end
      abort "Riak service failed to start" unless ready

      # This will fail a few times before it passes.
      # If this isn't done, the Riak::Client will fail to connect.
      puts "-> Waiting for Riak to be ready..."
      ready = false
      10.times do
        ready = %x[riak-admin test 2>/dev/null] =~ /Success/
        break if ready
        sleep 1
      end
      abort "Riak service is not ready." unless ready
    end

    def load_data
      puts "Loading Data..."
      100.times do |n|
        robj = riak_bucket.new "key_#{ n }"
        robj.data = n
        robj.store
      end
    end

    private

    def riak_bucket
      riak_client.bucket('backup-test')
    end

    def riak_client
      @riak_client ||= Riak::Client.new
    end
  end
end
