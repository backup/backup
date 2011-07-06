# encoding: utf-8

##
# Require the tempfile Ruby library when Backup::Encryptor::GPG is loaded
require 'tempfile'

module Backup
  module Encryptor
    class GPG < Base

      ##
      # The GPG Public key that'll be used to encrypt the backup
      attr_accessor :key

      ##
      # Contains the GPG encryption key id which'll be extracted from the public key file
      attr_accessor :encryption_key_id

      ##
      # Contains the temporary file with the public key
      attr_accessor :tmp_file

      ##
      # Creates a new instance of Backup::Encryptor::GPG and
      # sets the key to the provided GPG key. To enhance the DSL
      # the user may use tabs and spaces to indent the multi-line key string
      # since we gsub() every preceding 'space' and 'tab' on each line
      def initialize(&block)
        load_defaults!

        instance_eval(&block) if block_given?

        @key = key.gsub(/^[[:blank:]]+/, '')
      end

      ##
      # Performs the encrypting of the backup file and will
      # remove the unencrypted backup file, as well as the temp file
      def perform!
        log!
        write_tmp_file!
        extract_encryption_key_id!

        run("#{ utility(:gpg) } #{ options } -o '#{ Backup::Model.file }.gpg' '#{ Backup::Model.file }'")

        rm(Backup::Model.file)
        tmp_file.unlink

        Backup::Model.extension += '.gpg'
      end

    private

      ##
      # GPG options
      # Sets the gpg mode to 'encrypt' and passes in the encryption_key_id
      def options
        "-e --trust-model always -r '#{ encryption_key_id }'"
      end

      ##
      # Creates a new temp file and writes the provided public gpg key to it
      def write_tmp_file!
        @tmp_file = Tempfile.new('backup.pub')
        FileUtils.chown(USER, nil, @tmp_file)
        FileUtils.chmod(0600, @tmp_file)
        @tmp_file.write(key)
        @tmp_file.close
      end

      ##
      # Extracts the 'encryption key id' from the '@tmp_file'
      # and stores it in '@encryption_key_id'
      def extract_encryption_key_id!
        @encryption_key_id = run("#{ utility(:gpg) } --import '#{tmp_file.path}' 2>&1").match(/<(.+)>/)[1]
      end

    end
  end
end
