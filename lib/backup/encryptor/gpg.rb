# encoding: utf-8

module Backup
  module Encryptor
    ##
    # The GPG Encryptor allows you to encrypt your final archive using GnuPG,
    # using one of three {#mode modes} of operation.
    #
    # == First, setup defaults in your +config.rb+ file
    #
    # Configure the {#keys} Hash using {.defaults} in your +config.rb+
    # to specify all valid {#recipients} and their Public Key.
    #
    #   Backup::Encryptor::GPG.defaults do |encryptor|
    #     # setup all GnuPG public keys
    #     encryptor.keys = {}
    #     encryptor.keys['joe@example.com'] = <<-EOS
    #       # ...public key here...
    #     EOS
    #     encryptor.keys['mary@example.com'] = <<-EOS
    #       # ...public key here...
    #     EOS
    #   end
    #
    # The optional {#gpg_config} and {#gpg_homedir} options would also
    # typically be set using {.defaults} in +config.rb+ as well.
    #
    # == Then, setup each of your Models
    #
    # Set the desired {#recipients} and/or {#passphrase} (or {#passphrase_file})
    # for each {Model}, depending on the {#mode} used.
    #
    # === my_backup_01
    #
    # This archive can only be decrypted using the private key for joe@example.com
    #
    #   Model.new(:my_backup_01, 'Backup Job #1') do
    #     # ... archives, databases, compressor and storage options, etc...
    #     encrypt_with GPG do |encryptor|
    #       encryptor.mode = :asymmetric
    #       encryptor.recipients = 'joe@example.com'
    #     end
    #   end
    #
    # === my_backup_02
    #
    # This archive can only be decrypted using the passphrase "a secret".
    #
    #   Model.new(:my_backup_02, 'Backup Job #2') do
    #     # ... archives, databases, compressor and storage options, etc...
    #     encrypt_with GPG do |encryptor|
    #       encryptor.mode = :symmetric
    #       encryptor.passphrase = 'a secret'
    #     end
    #   end
    #
    # === my_backup_03
    #
    # This archive may be decrypted using either the private key for joe@example.com
    # *or* mary@example.com, *and* may also be decrypted using the passphrase.
    #
    #   Model.new(:my_backup_03, 'Backup Job #3') do
    #     # ... archives, databases, compressor and storage options, etc...
    #     encrypt_with GPG do |encryptor|
    #       encryptor.mode = :both
    #       encryptor.passphrase = 'a secret'
    #       encryptor.recipients = ['joe@example.com', 'mary@example.com']
    #     end
    #   end
    #
    class GPG < Base
      MODES = [:asymmetric, :symmetric, :both]

      ##
      # Sets the mode of operation.
      #
      # [:asymmetric]
      #   In this mode, the final backup archive will be encrypted using the
      #   public key(s) specified by the key identifiers in {#recipients}.
      #   The archive may then be decrypted by anyone with a private key that
      #   corresponds to one of the public keys used. See {#recipients} and
      #   {#keys} for more information.
      #
      # [:symmetric]
      #   In this mode, the final backup archive will be encrypted using the
      #   passphrase specified by {#passphrase} or {#passphrase_file}.
      #   The archive will be encrypted using the encryption algorithm
      #   specified in your GnuPG configuration. See {#gpg_config} for more
      #   information. Anyone with the passphrase may decrypt the archive.
      #
      # [:both]
      #   In this mode, both +:asymmetric+ and +:symmetric+ options are used.
      #   Meaning that the archive may be decrypted by anyone with a valid
      #   private key or by using the proper passphrase.
      #
      # @param mode [String, Symbol] Sets the mode of operation.
      #   (Defaults to +:asymmetric+)
      # @return [Symbol] mode that was set.
      # @raise [Backup::Errors::Encryptor::GPG::InvalidModeError]
      #   if mode given is invalid.
      #
      attr_reader :mode
      def mode=(mode)
        @mode = mode.to_sym
        raise Errors::Encryptor::GPG::InvalidModeError,
            "'#{ @mode }' is not a valid mode." unless MODES.include?(@mode)
      end

      ##
      # Specifies the GnuPG configuration to be used.
      #
      # This should be given as the text of a +gpg.conf+ file. It will be
      # written to a temporary file, which will be passed to the +gpg+ command
      # to use instead of the +gpg.conf+ found in the GnuPG home directory.
      # This allows you to be certain your preferences are used.
      #
      # This is especially useful if you've also set {#gpg_homedir} and plan
      # on allowing Backup to automatically create that directory and import
      # all your public keys specified in {#keys}. In this situation, that
      # folder would not contain any +gpg.conf+ file, so GnuPG would simply
      # use it's defaults.
      #
      # While this may be specified on a per-Model basis, you would generally
      # just specify this in the defaults. Leading tabs/spaces are stripped
      # before writing the given string to the temporary configuration file.
      #
      #   Backup::Encryptor::GPG.defaults do |enc|
      #     enc.gpg_config = <<-EOF
      #       # safely override preferences set in the receiver's public key(s)
      #       personal-cipher-preferences TWOFISH AES256 BLOWFISH AES192 CAST5 AES
      #       personal-digest-preferences SHA512 SHA256 SHA1 MD5
      #       personal-compress-preferences BZIP2 ZLIB ZIP Uncompressed
      #       # cipher algorithm for symmetric encryption
      #       # (if personal-cipher-preferences are not specified)
      #       s2k-cipher-algo TWOFISH
      #       # digest algorithm for mangling the symmetric encryption passphrase
      #       s2k-digest-algo SHA512
      #     EOF
      #   end
      #
      # @see #gpg_homedir
      # @return [String]
      attr_accessor :gpg_config

      ##
      # Set the GnuPG home directory to be used.
      #
      # This allows you to specify the GnuPG home directory on the system
      # where Backup will be run, keeping the keyrings used by Backup separate
      # from the default keyrings of the user running Backup.
      # By default, this would be +`~/.gnupg`+.
      #
      # If a directory is specified here, Backup will create it if needed
      # and ensure the correct permissions are set. All public keys Backup
      # imports would be added to the +pubring.gpg+ file within this directory,
      # and +gpg+ would be given this directory using it's +--homedir+ option.
      #
      # Any +gpg.conf+ file located in this directory would also be used by
      # +gpg+, unless {#gpg_config} is specified.
      #
      # The given path will be expanded before use.
      #
      # @return [String]
      attr_accessor :gpg_homedir

      ##
      # Specifies a Hash of public key identifiers and their public keys.
      #
      # While not _required_, it is recommended that all public keys you intend
      # to use be setup in {#keys}. The best place to do this is in your defaults
      # in +config.rb+.
      #
      #   Backup::Encryptor::GPG.defaults do |enc|
      #     enc.keys = {}
      #
      #     enc.keys['joe@example.com'] = <<-EOS
      #       -----BEGIN PGP PUBLIC KEY BLOCK-----
      #       Version: GnuPG v1.4.12 (GNU/Linux)
      #
      #       mQMqBEd5F8MRCACfArHCJFR6nkmxNiW+UE4PAW3bQla9JWFqCwu4VqLkPI/lHb5p
      #       xHff8Fzy2O89BxD/6hXSDx2SlVmAGHOCJhShx1vfNGVYNsJn2oNK50in9kGvD0+m
      #       [...]
      #       SkQEHOxhMiFjAN9q4LuirSOu65uR1bnTmF+Z92++qMIuEkH4/LnN
      #       =8gNa
      #       -----END PGP PUBLIC KEY BLOCK-----
      #     EOS
      #
      #     enc.keys['mary@example.com'] = <<-EOS
      #       -----BEGIN PGP PUBLIC KEY BLOCK-----
      #       Version: GnuPG v1.4.12 (GNU/Linux)
      #
      #       2SlVmAGHOCJhShx1vfNGVYNxHff8Fzy2O89BxD/6in9kGvD0+mhXSDxsJn2oNK50
      #       kmxNiW+UmQMqBEd5F8MRCACfArHCJFR6qCwu4VqLkPI/lHb5pnE4PAW3bQla9JWF
      #       [...]
      #       AN9q4LSkQEHOxhMiFjuirSOu65u++qMIuEkH4/LnNR1bnTmF+Z92
      #       =8gNa
      #       -----END PGP PUBLIC KEY BLOCK-----
      #
      #     EOS
      #   end
      #
      # All leading spaces/tabs will be stripped from the key, so the above
      # form may be used to set each identifier's key.
      #
      # When a public key can not be found for an identifier specified in
      # {#recipients}, the corresponding public key from this Hash will be
      # imported into +pubring.gpg+ in the GnuPG home directory ({#gpg_homedir}).
      # Therefore, each key *must* be the same identifier used in {#recipients}.
      #
      # To obtain the public key in ASCII format, use:
      #
      #   $ gpg -a --export joe@example.com
      #
      # See {#recipients} for information on what may be used as valid identifiers.
      #
      # @return [Hash]
      attr_accessor :keys

      ##
      # @deprecated Use {#keys} and {#recipients}.
      # @!attribute key
      attr_deprecate :key,
        :version => '3.0.26',
        :message => "This has been replaced with #keys and #recipients",
        :action  => lambda {|klass, val|
          identifier = klass.send(:import_key, 'deprecated :key', val)
          klass.recipients = identifier
        }

      ##
      # Specifies the recipients to use when encrypting the backup archive.
      #
      # When {#mode} is set to +:asymmetric+ or +:both+, the public key for
      # each recipient given here will be used to encrypt the archive. Each
      # recipient will be able to decrypt the archive using their private key.
      #
      # If there is only one recipient, this may be specified as a String.
      # Otherwise, this should be an Array of Strings. Each String must be a
      # valid public key identifier, and *must* be the same identifier used to
      # specify the recipient's public key in {#keys}. This is so that if a
      # public key is not found for the given identifier, it may be imported
      # from {#keys}.
      #
      # Valid identifiers which may be used are as follows:
      #
      # [Key Fingerprint]
      #   The key fingerprint is a 40-character hex string, which uniquely
      #   identifies a public key. This may be obtained using the following:
      #
      #     $ gpg --fingerprint john.smith@example.com
      #     pub   1024R/4E5E8D8A 2012-07-20
      #     Key fingerprint = FFEA D1DB 201F B214 873E  7399 4A83 569F 4E5E 8D8A
      #     uid                  John Smith <john.smith@example.com>
      #     sub   1024R/92C8DFD8 2012-07-20
      #
      # [Long Key ID]
      #   The long Key ID is the last 16-characters of the key's fingerprint.
      #
      #   The Long Key ID in this example is: 4A83569F4E5E8D8A
      #
      #     $ gpg --keyid-format long -k john.smith@example.com
      #     pub   1024R/4A83569F4E5E8D8A 2012-07-20
      #     uid                          John Smith <john.smith@example.com>
      #     sub   1024R/662F18DB92C8DFD8 2012-07-20
      #
      # [Short Key ID]
      #   The short Key ID is the last 8-characters of the key's fingerprint.
      #   This is the default key format seen when listing keys.
      #
      #   The Short Key ID in this example is: 4E5E8D8A
      #
      #     $ gpg -k john.smith@example.com
      #     pub   1024R/4E5E8D8A 2012-07-20
      #     uid                  John Smith <john.smith@example.com>
      #     sub   1024R/92C8DFD8 2012-07-20
      #
      # [Email Address]
      #   This must exactly match an email address for one of the UID records
      #   associated with the recipient's public key.
      #
      # Recipient identifier forms may be mixed, as long as the identifier used
      # here is the same as that used in {#keys}. Also, all spaces will be stripped
      # from the identifier when used, so the following would be valid.
      #
      #   Backup::Model.new(:my_backup, 'My Backup') do
      #     encrypt_with GPG do |enc|
      #       enc.recipients = [
      #         # John Smith
      #         '4A83 569F 4E5E 8D8A',
      #         # Mary Smith
      #         'mary.smith@example.com'
      #       ]
      #     end
      #   end
      #
      # @return [String, Array]
      attr_accessor :recipients

      ##
      # Specifies the passphrase to use symmetric encryption.
      #
      # When {#mode} is +:symmetric+ or +:both+, this passphrase will be used
      # to symmetrically encrypt the archive.
      #
      # Use of this option will override the use of {#passphrase_file}.
      #
      # @return [String]
      attr_accessor :passphrase

      ##
      # Specifies the passphrase file to use symmetric encryption.
      #
      # When {#mode} is +:symmetric+ or +:both+, this file will be passed
      # to the +gpg+ command line, where +gpg+ will read the first line from
      # this file and use it for the passphrase.
      #
      # The file path given here will be expanded to a full path.
      #
      # If {#passphrase} is specified, {#passphrase_file} will be ignored.
      # Therefore, if you have set {#passphrase} in your global defaults,
      # but wish to use {#passphrase_file} with a specific {Model}, be sure
      # to clear {#passphrase} within that model's configuration.
      #
      #   Backup::Encryptor::GPG.defaults do |enc|
      #     enc.passphrase = 'secret phrase'
      #   end
      #
      #   Backup::Model.new(:my_backup, 'My Backup') do
      #     # other directives...
      #     encrypt_with GPG do |enc|
      #       enc.mode = :symmetric
      #       enc.passphrase = nil
      #       enc.passphrase_file = '/path/to/passphrase.file'
      #     end
      #   end
      #
      # @return [String]
      attr_accessor :passphrase_file

      ##
      # Configures default accessor values for new class instances.
      #
      # If all required options are set, then no further configuration
      # would be needed within a Model's definition when an Encryptor is added.
      # Therefore, the following example is sufficient to encrypt +:my_backup+:
      #
      #   # Defaults set in config.rb
      #   Backup::Encryptor::GPG.defaults do |encryptor|
      #     encryptor.keys = {}
      #     encryptor.keys['joe@example.com'] = <<-EOS
      #       -----BEGIN PGP PUBLIC KEY BLOCK-----
      #       Version: GnuPG v1.4.12 (GNU/Linux)
      #
      #       mI0EUBR6CwEEAMVSlFtAXO4jXYnVFAWy6chyaMw+gXOFKlWojNXOOKmE3SujdLKh
      #       kWqnafx7VNrb8cjqxz6VZbumN9UgerFpusM3uLCYHnwyv/rGMf4cdiuX7gGltwGb
      #       (...etc...)
      #       mLekS3xntUhhgHKc4lhf4IVBqG4cFmwSZ0tZEJJUSESb3TqkkdnNLjE=
      #       =KEW+
      #       -----END PGP PUBLIC KEY BLOCK-----
      #     EOS
      #
      #     encryptor.recipients = 'joe@example.com'
      #   end
      #
      #   # Encryptor set in the model
      #   Backup::Model.new(:my_backup, 'My Backup') do
      #     # archives, storage options, etc...
      #     encrypt_with GPG
      #   end
      #
      # @!scope class
      # @see Configuration::Helpers::ClassMethods#defaults
      # @yield [config] OpenStruct object
      # @!method defaults

      ##
      # Creates a new instance of Backup::Encryptor::GPG.
      #
      # This constructor is not used directly when configuring Backup.
      # Use {Model#encrypt_with}.
      #
      #   Model.new(:backup_trigger, 'Backup Label') do
      #     archive :my_archive do |archive|
      #       archive.add '/some/directory'
      #     end
      #
      #     compress_with Gzip
      #
      #     encrypt_with GPG do |encryptor|
      #       encryptor.mode = :both
      #       encryptor.passphrase = 'a secret'
      #       encryptor.recipients = ['joe@example.com', 'mary@example.com']
      #     end
      #
      #     store_with SFTP
      #
      #     notify_by Mail
      #   end
      #
      # @api private
      def initialize(&block)
        super

        instance_eval(&block) if block_given?

        @mode ||= :asymmetric
      end

      ##
      # This is called as part of the procedure run by the Packager.
      # It sets up the needed options to pass to the gpg command,
      # then yields the command to use as part of the packaging procedure.
      # Once the packaging procedure is complete, it will return
      # so that any clean-up may be performed after the yield.
      # Cleanup is also ensured, as temporary files may hold sensitive data.
      # If no options can be built, the packaging process will be aborted.
      #
      # @api private
      def encrypt_with
        log!
        prepare

        if mode_options.empty?
          raise Errors::Encryptor::GPG::EncryptionError,
              "Encryption could not be performed for mode '#{ mode }'"
        end

        yield "#{ utility(:gpg) } #{ base_options } #{ mode_options }", '.gpg'

      ensure
        cleanup
      end

      private

      ##
      # Remove any temporary directories and reset all instance variables.
      #
      def prepare
        FileUtils.rm_rf(@tempdirs, :secure => true) if @tempdirs
        @tempdirs = []
        @base_options = nil
        @mode_options = nil
        @user_recipients = nil
        @user_keys = nil
        @system_identifiers = nil
      end
      alias :cleanup :prepare

      ##
      # Returns the options needed for the gpg command line which are
      # not dependant on the #mode. --no-tty supresses output of certain
      # messages, like the "Reading passphrase from file descriptor..."
      # messages during symmetric encryption
      #
      def base_options
        @base_options ||= begin
          opts = ['--no-tty']
          path = setup_gpg_homedir
          opts << "--homedir '#{ path }'" if path
          path = setup_gpg_config
          opts << "--options '#{ path }'" if path
          opts.join(' ')
        end
      end

      ##
      # Setup the given :gpg_homedir if needed, ensure the proper permissions
      # are set, and return the directory's path. Otherwise, return false.
      #
      # If the GnuPG files do not exist, trigger their creation by requesting
      # --list-secret-keys. Some commands, like for symmetric encryption, will
      # issue messages about their creation on STDERR, which generates unwanted
      # warnings in the log. This way, if any of these files are created here,
      # we will get those messages on STDOUT for the log, without the actual
      # secret key listing which we don't care about.
      #
      def setup_gpg_homedir
        return false unless gpg_homedir

        path = File.expand_path(gpg_homedir)
        FileUtils.mkdir_p(path)
        FileUtils.chown(Config.user, nil, path)
        FileUtils.chmod(0700, path)

        unless %w{ pubring.gpg secring.gpg trustdb.gpg }.
            all? {|name| File.exist? File.join(path, name) }
          run("#{ utility(:gpg) } --homedir '#{ path }' -K 2>&1 >/dev/null")
        end

        path

      rescue => err
        raise Errors::Encryptor::GPG::HomedirError.wrap(
            err, "Failed to create or set permissions for #gpg_homedir")
      end

      ##
      # Write the given #gpg_config to a tempfile, within a tempdir, and
      # return the file's path to be given to the gpg --options argument.
      # If no #gpg_config is set, return false.
      #
      # This is required in order to set the proper permissions on the
      # directory containing the tempfile. The tempdir will be removed
      # after the packaging procedure is completed.
      #
      # Once written, we'll call check_gpg_config to make sure there are
      # no problems that would prevent gpg from running with this config.
      # If any errors occur during this process, we can not proceed.
      # We'll cleanup to remove the tempdir (if created) and raise an error.
      #
      def setup_gpg_config
        return false unless gpg_config

        dir = Dir.mktmpdir('backup-gpg_config', Config.tmp_path)
        @tempdirs << dir
        file = Tempfile.open('backup-gpg_config', dir)
        file.write gpg_config.gsub(/^[[:blank:]]+/, '')
        file.close

        check_gpg_config(file.path)

        file.path

      rescue => err
        cleanup
        raise Errors::Encryptor::GPG::GPGConfigError.wrap(
            err, "Error creating temporary file for #gpg_config.")
      end

      ##
      # Make sure the temporary GnuPG config file created from #gpg_config
      # does not have any syntax errors that would prevent gpg from running.
      # If so, raise the returned error message.
      # Note that Cli::Helpers#run may also raise an error here.
      #
      def check_gpg_config(path)
        ret = run(
          "#{ utility(:gpg) } --options '#{ path }' --gpgconf-test 2>&1"
        ).chomp
        raise ret unless ret.empty?
      end

      ##
      # Returns the options needed for the gpg command line to perform
      # the encryption based on the #mode.
      #
      def mode_options
        @mode_options ||= begin
          s_opts = symmetric_options if mode != :asymmetric
          a_opts = asymmetric_options if mode != :symmetric
          [s_opts, a_opts].compact.join(' ')
        end
      end

      ##
      # Process :passphrase or :passphrase_file and return the command line
      # options to perform symmetric encryption. If no :passphrase is
      # specified, or an error occurs creating a temporary file for it, then
      # try to use :passphrase_file if it's set.
      # If the option can not be set, log a warning and return nil.
      #
      def symmetric_options
        path = setup_passphrase_file
        unless path || passphrase_file.to_s.empty?
          path = File.expand_path(passphrase_file.to_s)
        end

        if path && File.exist?(path)
          "-c --passphrase-file '#{ path }'"
        else
          Logger.warn("Symmetric encryption options could not be set.")
          nil
        end
      end

      ##
      # Create a temporary file, within a tempdir, to hold the :passphrase and
      # return the file's path. If an error occurs, log a warning.
      # Return false if no :passphrase is set or an error occurs.
      #
      def setup_passphrase_file
        return false if passphrase.to_s.empty?

        dir = Dir.mktmpdir('backup-gpg_passphrase', Config.tmp_path)
        @tempdirs << dir
        file = Tempfile.open('backup-gpg_passphrase', dir)
        file.write passphrase.to_s
        file.close

        file.path

      rescue => err
        Logger.warn Errors::Encryptor::GPG::PassphraseError.wrap(
            err, "Error creating temporary passphrase file.")
        false
      end

      ##
      # Process :recipients, importing their public key from :keys if needed,
      # and return the command line options to perform asymmetric encryption.
      # Log a warning and return nil if no valid recipients are found.
      #
      def asymmetric_options
        if user_recipients.empty?
          Logger.warn "No recipients available for asymmetric encryption."
          nil
        else
          # skip trust database checks
          "-e --trust-model always " +
              user_recipients.map {|r| "-r '#{ r }'" }.join(' ')
        end
      end

      ##
      # Returns an Array of the public key identifiers the user specified
      # in :recipients. Each identifier is 'cleaned' so that exact matches
      # can be performed. Then each is checked to ensure it will find a
      # public key that exists in the system's public keyring.
      # If the identifier does not match an existing key, the public key
      # associated with the identifier in :keys will be imported for use.
      # If no key can be found in the system or in :keys for the identifier,
      # a warning will be issued; as we will attempt to encrypt the backup
      # and proceed if at all possible.
      #
      def user_recipients
        @user_recipients ||= begin
          [recipients].flatten.compact.map do |identifier|
            identifier = clean_identifier(identifier)
            if system_identifiers.include?(identifier)
              identifier
            else
              key = user_keys[identifier]
              if key
                # will log a warning and return nil if the import fails
                import_key(identifier, key)
              else
                Logger.warn(
                  "No public key was found in #keys for '#{ identifier }'"
                )
                nil
              end
            end
          end.compact
        end
      end

      ##
      # Returns the #keys hash set by the user with all identifiers
      # (Hash keys) 'cleaned' for exact matching. If the cleaning process
      # creates duplicate keys, the user will be warned.
      #
      def user_keys
        @user_keys ||= begin
          _keys = keys || {}
          ret = Hash[_keys.map {|k,v| [clean_identifier(k), v] }]
          Logger.warn(
            "Duplicate public key identifiers were detected in #keys."
          ) if ret.keys.count != _keys.keys.count
          ret
        end
      end

      ##
      # Cleans a public key identifier.
      # Strip out all spaces, upcase non-email identifiers,
      # and wrap email addresses in <> to perform exact matching.
      #
      def clean_identifier(str)
        str = str.to_s.gsub(/[[:blank:]]+/, '')
        str =~ /@/ ? "<#{ str.gsub(/(<|>)/,'') }>" : str.upcase
      end

      ##
      # Import the given public key and return the 16 character Key ID.
      # If the import fails, return nil.
      # Note that errors raised by Cli::Helpers#run may also be rescued here.
      #
      def import_key(identifier, key)
        file = Tempfile.open('backup-gpg_import', Config.tmp_path)
        file.write(key.gsub(/^[[:blank:]]+/, ''))
        file.close
        ret = run(
          "#{ utility(:gpg) } #{ base_options } " +
          "--keyid-format 0xlong --import '#{ file.path }' 2>&1"
        )
        file.delete

        keyid = ret.match(/ 0x(\w{16})/).to_a[1]
        raise "GPG Returned:\n#{ ret.gsub(/^\s*/, '  ') }" unless keyid
        keyid

      rescue => err
        Logger.warn Errors::Encryptor::GPG::KeyImportError.wrap(
            err, "Public key import failed for '#{ identifier }'")
        nil
      end

      ##
      # Parse the information for all the public keys found in the public
      # keyring (based on #gpg_homedir setting) and return an Array of all
      # identifiers which could be used to specify a valid key.
      #
      def system_identifiers
        @system_identifiers ||= begin
          skip_key = false
          data = run(
            "#{ utility(:gpg) } #{ base_options } " +
            "--with-colons --fixed-list-mode --fingerprint"
          )
          data.lines.map do |line|
            line.strip!

            # process public key record
            if line =~ /^pub:/
              validity, keyid, capabilities =
                  line.split(':').values_at(1, 4, 11)
              # skip keys marked as revoked ('r'), expired ('e'),
              # invalid ('i') or disabled ('D')
              if validity[0,1] =~ /(r|e|i)/ || capabilities =~ /D/
                skip_key = true
                next nil
              else
                skip_key = false
                # return both the long and short id
                next [keyid[-8..-1], keyid]
              end
            else
              # wait for the next valid public key record
              next nil if skip_key

              # process UID records for the current public key
              if line =~ /^uid:/
                validity, userid = line.split(':').values_at(1, 9)
                # skip records marked as revoked ('r'), expired ('e')
                # or invalid ('i')
                if validity !~ /(r|e|i)/
                  # return the last email found in user id string,
                  # since this includes user supplied comments.
                  # return nil if no email found.
                  email, str = nil, userid
                  while match = str.match(/<.+?@.+?>/)
                    email, str = match[0], match.post_match
                  end
                  next email
                end
              # return public key's fingerprint
              elsif line =~ /^fpr:/
                next line.split(':')[9]
              end

              nil # ignore any other lines
            end
          end.flatten.compact
        end
      end

    end
  end
end
