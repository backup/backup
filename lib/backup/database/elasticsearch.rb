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
      # eg. logstash-2013-04-11
      #
      attr_accessor :index

      ##
      # Determines whether Backup should close the index with the
      # Elasticsearch API before copying the index directory.
      #
      attr_accessor :invoke_close

      ##
      # Elasticsearch API options for the +invoke_close+ option.
      attr_accessor :host, :port

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @name ||= 'logstash-' + (Date.today-1).strftime("%Y.%m.%d")
        @host ||= 'localhost'
        @port ||= 9200
      end

      ##
      # Tars and optionally compresses the Elasticsearch index
      # folder to the +dump_path+ using the +dump_filename+.
      #
      #   <trigger>/databases/Eliasticsearch[-<database_id>].tar[.gz]
      #
      # If +invoke_close+ is true, `POST $index/_close` will be invoked.
      def perform!
        super

        invoke_close! if invoke_close
        copy!

        log!(:finished)
      end

      private

      def close_index_cmd
        "curl -iXPOST http://#{ host }:#{ port }/#{ index }/_close"
      end

      def invoke_close!
        resp = run(close_index_cmd)
        unless resp =~ /200 OK/
          raise Errors::Database::Elasticsearch::CommandError, <<-EOS
            Could not invoke the close index command.
            Command was: #{ close_index_cmd }
            Response was: #{ resp }
          EOS
        end
      end

      def copy!
        src_path = File.join(path, 'nodes/0/indices', index)
        unless File.exist?(src_path)
          raise Errors::Database::Elasticsearch::NotFoundError, <<-EOS
            Elasticsearch index directory not found
            Folder path was #{ src_path }
          EOS
        end

        dst_path = File.join(dump_path, dump_filename + '.tar')
        cmd = "tar -cf - #{ src_path } |"
        if model.compressor
          model.compressor.compress_with do |comp_cmd, ext|
            run("#{ cmd } #{ comp_cmd } -c '#{ src_path }' > '#{ dst_path + ext }'")
          end
        else
          run("#{ cmd } > '#{ dst_path }'")
        end
      end

    end
  end
end
