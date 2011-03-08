# encoding: utf-8

module Backup
  module Configuration
    module Encryptor
      class GPG < Base
        class << self

          ##
          # The GPG Public key that'll be used to encrypt the backup
          attr_accessor :key

        end
      end
    end
  end
end
