# encoding: utf-8

module Backup
  module Database
    class Elasticsearch < Base

      ##
      # Elasticsearch data directory path.
      #
      # This is set in `elasticsearch.yml`.
      #   path:
      #     data: /var/data/elasticsearch
      #
      # eg. /var/data/elasticsearch
      #
      attr_accessor :path

      ##
      # Elasticsearch index name to backup.
      #
      # To backup all indexes, set this to `:all` or leave blank.
      #
      attr_accessor :index

      ##
      # Determines whether Backup should flush the index with the
      # Elasticsearch API before copying the index directory.
      #
      attr_accessor :invoke_flush

      ##
      # Determines whether Backup should close the index with the
      # Elasticsearch API before copying the index directory.
      #
      attr_accessor :invoke_close

      ##
      # Elasticsearch API options for the +invoke_flush+ and
      # +invoke_close+ options.
      attr_accessor :host, :port

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @index ||= :all
        @host ||= 'localhost'
        @port ||= 9200
      end

      ##
      # Tars and optionally compresses the Elasticsearch index
      # folder to the +dump_path+ using the +dump_filename+.
      #
      #   <trigger>/databases/Eliasticsearch[-<database_id>].tar[.gz]
      #
      # If +invoke_flush+ is true, `POST $index/_flush` will be invoked.
      # If +invoke_close+ is true, `POST $index/_close` will be invoked.
      def perform!
        super

        invoke_flush! if invoke_flush
        unless backup_all?
          invoke_close! if invoke_close
        end
        copy!

        log!(:finished)
      end

      private

      def backup_all?
        [:all, ':all', 'all'].include?(index)
      end

      def api_request(http_method, endpoint, body=nil)
        http = Net::HTTP.new(host, port)
        request = case http_method.to_sym
        when :post
          Net::HTTP::Post.new(endpoint)
        end
        request.body = body
        begin
          Timeout::timeout(180) do
            http.request(request)
          end
        rescue => error
          raise Errors::Database::Elasticsearch::QueryError, <<-EOS
            Could not query the Elasticsearch API.
            Host was: #{ host }
            Port was: #{ port }
            Endpoint was: #{ endpoint }
            Error was: #{ error.message }
          EOS
        end
      end

      def flush_index_endpoint
        backup_all? ? '/_flush' : "/#{ index }/_flush"
      end

      def invoke_flush!
        response = api_request(:post, flush_index_endpoint)
        unless response.code == '200'
          raise Errors::Database::Elasticsearch::QueryError, <<-EOS
            Could not flush the Elasticsearch index.
            Host was: #{ host }
            Port was: #{ port }
            Endpoint was: #{ flush_index_endpoint }
            Response body was: #{ response.body }
            Response code was: #{ response.code }
          EOS
        end
      end

      def close_index_endpoint
        "/#{ index }/_close"
      end

      def invoke_close!
        response = api_request(:post, close_index_endpoint)
        unless response.code == '200'
          raise Errors::Database::Elasticsearch::QueryError, <<-EOS
            Could not close the Elasticsearch index.
            Host was: #{ host }
            Port was: #{ port }
            Endpoint was: #{ close_index_endpoint }
            Response body was: #{ response.body }
            Response code was: #{ response.code }
          EOS
        end
      end

      def copy!
        src_path = File.join(path, 'nodes/0/indices')
        src_path = File.join(src_path, index) unless backup_all?
        unless File.exist?(src_path)
          raise Errors::Database::Elasticsearch::NotFoundError, <<-EOS
            Elasticsearch index directory not found
            Directory path was #{ src_path }
          EOS
        end
        pipeline = Pipeline.new
        pipeline << "#{ utility(:tar) } -cf - #{ src_path }"
        dst_ext = '.tar'
        if model.compressor
          model.compressor.compress_with do |cmd, ext|
            pipeline << cmd
            dst_ext << ext
          end
        end
        dst_path = File.join(dump_path, dump_filename + dst_ext)
        pipeline << "#{ utility(:cat) } > '#{ dst_path }'"
        pipeline.run
      end

    end
  end
end
