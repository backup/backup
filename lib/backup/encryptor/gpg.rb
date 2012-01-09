# encoding: utf-8

module Backup
  module Encryptor
    class GPG < Base

      ##
      # The GPG Public key that'll be used to encrypt the backup
      attr_accessor :key

      ##
      # Creates a new instance of Backup::Encryptor::GPG and
      # sets the key to the provided GPG key. To enhance the DSL
      # the user may use tabs and spaces to indent the multi-line key string
      # since we gsub() every preceding 'space' and 'tab' on each line
      def initialize(&block)
        super

        instance_eval(&block) if block_given?
      end

      ##
      # This is called as part of the procedure run by the Packager.
      # It sets up the needed encryption_key_email to pass to the gpg command,
      # then yields the command to use as part of the packaging procedure.
      # Once the packaging procedure is complete, it will return
      # so that any clean-up may be performed after the yield.
      def encrypt_with
        log!
        extract_encryption_key_email!

        yield "#{ utility(:gpg) } #{ options }", '.gpg'
      end

      private

      ##
      # Imports the given encryption key to ensure it's available for use,
      # and extracts the email address used to create the key.
      # This is stored in '@encryption_key_email', to be used to specify
      # the --recipient when performing encryption so this key is used.
      def extract_encryption_key_email!
        if @encryption_key_email.to_s.empty?
          with_tmp_key_file do |tmp_file|
            @encryption_key_email = run(
              "#{ utility(:gpg) } --import '#{tmp_file}' 2>&1"
            ).match(/<(.+)>/)[1]
          end
        end
      end

      ##
      # GPG options
      # Sets the gpg mode to 'encrypt' and passes in the encryption_key_email
      def options
        "-e --trust-model always -r '#{ @encryption_key_email }'"
      end

      ##
      # Writes the provided public gpg key to a temp file,
      # yields the path, then deletes the file when the block returns.
      def with_tmp_key_file
        tmp_file = Tempfile.new('backup.pub')
        FileUtils.chown(Config.user, nil, tmp_file.path)
        FileUtils.chmod(0600, tmp_file.path)
        tmp_file.write(encryption_key)
        tmp_file.close
        yield tmp_file.path
        tmp_file.delete
      end

      ##
      # Returns the encryption key with preceding spaces and tabs removed
      def encryption_key
        key.gsub(/^[[:blank:]]+/, '')
      end

    end
  end
end
