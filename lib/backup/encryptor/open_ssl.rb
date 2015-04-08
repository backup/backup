# encoding: utf-8

module Backup
  module Encryptor
    class OpenSSL < Base

      ##
      # The password that'll be used to encrypt the backup. This
      # password will be required to decrypt the backup later on.
      attr_accessor :password

      ##
      # The password file to use to encrypt the backup.
      attr_accessor :password_file

      ##
      # Determines whether the 'base64' should be used or not
      attr_accessor :base64

      ##
      # Determines whether the 'salt' flag should be used
      attr_accessor :salt

      ##
      # Creates a new instance of Backup::Encryptor::OpenSSL and
      # sets the password attribute to what was provided
      def initialize(&block)
        super

        @base64        ||= false
        @salt          ||= true
        @password_file ||= nil

        instance_eval(&block) if block_given?
      end

      ##
      # This is called as part of the procedure run by the Packager.
      # It sets up the needed options to pass to the openssl command,
      # then yields the command to use as part of the packaging procedure.
      # Once the packaging procedure is complete, it will return
      # so that any clean-up may be performed after the yield.
      def encrypt_with
        log!
        yield "#{ utility(:openssl) } #{ options }", '.enc'
      end

      private

      ##
      # Uses the 256bit AES encryption cipher, which is what the
      # US Government uses to encrypt information at the "Top Secret" level.
      #
      # The -base64 option will make the encrypted output base64 encoded,
      # this makes the encrypted file readable using text editors
      #
      # The -salt option adds strength to the encryption
      #
      # Always sets a password option, if even no password is given,
      # but will prefer the password_file option if both are given.
      def options
        opts = ['aes-256-cbc']
        opts << '-base64' if @base64
        opts << '-salt'   if @salt

        if @password_file.to_s.empty?
          opts << "-k #{Shellwords.escape(@password)}"
        else
          opts << "-pass file:#{@password_file}"
        end

        opts.join(' ')
      end

    end
  end
end
