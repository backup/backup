# encoding: utf-8

module Backup
  module CloudIO
    class Error < Backup::Error; end
    class FileSizeError < Backup::Error; end

    class Base
      attr_reader :max_retries, :retry_waitsec

      def initialize(options = {})
        @max_retries    = options[:max_retries]
        @retry_waitsec  = options[:retry_waitsec]
      end

      private

      def with_retries(operation)
        retries = 0
        begin
          yield
        rescue => err
          retries += 1
          raise Error.wrap(err, <<-EOS) if retries > max_retries
            Max Retries (#{ max_retries }) Exceeded!
            Operation: #{ operation }
            Be sure to check the log messages for each retry attempt.
          EOS

          Logger.info Error.wrap(err, <<-EOS)
            Retry ##{ retries } of #{ max_retries }
            Operation: #{ operation }
          EOS
          sleep(retry_waitsec)
          retry
        end
      end

    end
  end
end
