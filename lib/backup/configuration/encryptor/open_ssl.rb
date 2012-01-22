# encoding: utf-8

module Backup
  module Configuration
    module Encryptor
      class OpenSSL < Base
        class << self

          ##
          # The password that'll be used to encrypt the backup. This
          # password will be required to decrypt the backup later on.
          attr_accessor :password

          ##
          # The password file used for encrypting the backup.  This
          # password file will be required to decrypt the backup later
          # on.
          attr_accessor :password_file

          ##
          # Determines whether the 'base64' should be used or not
          attr_accessor :base64

          ##
          # Determines whether the 'salt' flag should be used
          attr_accessor :salt

        end
      end
    end
  end
end
