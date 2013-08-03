# encoding: utf-8
require 'uri'
require 'rest_client'

module Backup
  module Storage
    class HttpPost < Base

      ##
      # URI to post backup to
      ##
      attr_accessor :uri

      ##
      # Hash of additional HTTP headers to send
      ##
      attr_accessor :headers

      def initialize(model, storage_id = nil)
        super
      end

      private

      def transfer!

        package.filenames.each do |filename|
          src = "#{ File.join(Config.tmp_path, filename) }"
          headers_hash = { "User-Agent" => "Backup/#{ VERSION }" }.merge(headers).reject {|k,v| v.nil? }
          RestClient::Request.execute(:method => :post, :url => uri, :payload => {"backup[file]" => File.new(src, "rb")}, :headers => headers_hash)
        end

      end

    end
  end
end
