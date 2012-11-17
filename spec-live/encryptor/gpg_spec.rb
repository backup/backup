# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Encryptor::GPG',
    :if => Backup::SpecLive::CONFIG['encryptor']['gpg']['specs_enabled'] do

  def archive_file_for(model)
    File.join(
      Backup::SpecLive::TMP_PATH,
      "#{model.trigger}", model.time, "#{model.trigger}.tar.gpg"
    )
  end

  # clear out, then load the encryptor.gpg_homedir with the keys for the
  # given key_type (:public/:private) for the given identifiers.
  #
  def load_gpg_homedir(encryptor, key_type, identifiers)
    # Clear out any files if the directory exists
    dir = File.expand_path(encryptor.gpg_homedir)
    FileUtils.rm(Dir[File.join(dir, '*')]) if File.exists?(dir)

    # Make sure the directory exists with proper permissions.
    # This will also initialize the keyring files, so this method can be
    # called with no identifiers to simply reset the directory without
    # importing any keys.
    encryptor.send(:setup_gpg_homedir)

    # Import the keys, making sure each import is successful.
    # #import_key will log a warning for the identifier if the
    # import fails, so we'll just abort if we get a failure here.
    [identifiers].flatten.compact.each do |identifier|
      ret_id = encryptor.send(:import_key,
        identifier, Backup::SpecLive::GPGKeys[identifier][key_type]
      )
      unless ret_id == Backup::SpecLive::GPGKeys[identifier][:long_id]
        abort("load_gpg_homedir failed")
      end
    end
  end

  # make sure the archive can be decrypted
  def can_decrypt?(model, passphrase = nil)
    enc = model.encryptor
    archive = archive_file_for(model)
    outfile = File.join(File.dirname(archive), 'outfile')

    pass_opt = "--passphrase '#{ passphrase }'" if passphrase
    enc.send(:run,
      "#{ enc.send(:utility, :gpg) } #{ enc.send(:base_options) } " +
      "#{ pass_opt } -o '#{ outfile }' -d '#{ archive }' 2>&1"
    )

    if File.exist?(outfile)
      File.delete(outfile)
      true
    else
      false
    end
  end

  context 'using :asymmetric mode with some existing keys' do
    let(:model) { h_set_trigger('encryptor_gpg_asymmetric') }

    it 'should encrypt the archive' do
      recipients = [:backup01, :backup02, :backup03, :backup04]
      # Preload keys for backup01 and backup02.
      # Keys for backup03 and backup04 are configured in :keys in the model
      # and will be imported when the model is performed.
      # The Model specifies all 4 as :recipients.
      load_gpg_homedir(model.encryptor, :public, recipients[0..1])

      model.perform!

      Backup::Logger.has_warnings?.should be_false

      File.exist?(archive_file_for(model)).should be_true

      # make sure all 4 recipients can decrypt the archive
      recipients.each do |recipient|
        load_gpg_homedir(model.encryptor, :private, recipient)
        can_decrypt?(model).should be_true
      end
    end
  end # context 'using :asymmetric mode with some existing keys'

  context 'using :asymmetric mode with a missing public key' do
    let(:model) { h_set_trigger('encryptor_gpg_asymmetric_missing') }

    # backup01 will be preloaded.
    # backup02 will be imported from :keys
    # backupfoo will be a missing recipient
    it 'should encrypt the archive' do
      load_gpg_homedir(model.encryptor, :public, :backup01)

      model.perform!

      Backup::Logger.has_warnings?.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /No public key was found in #keys for '<backupfoo@foo.com>'/
      }.should be_true

      File.exist?(archive_file_for(model)).should be_true

      [:backup01, :backup02].each do |recipient|
        load_gpg_homedir(model.encryptor, :private, recipient)
        can_decrypt?(model).should be_true
      end
    end
  end # context 'using :asymmetric mode with a missing public key'

  context 'using :asymmetric mode with no valid public keys' do
    let(:model) { h_set_trigger('encryptor_gpg_asymmetric_fail') }

    it 'should abort the backup' do
      model.perform!

      # issues warnings about the missing keys
      Backup::Logger.has_warnings?.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /No public key was found in #keys for '<backupfoo@foo.com>'/
      }.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /No public key was found in #keys for '<backupfoo2@foo.com>'/
      }.should be_true

      # issues warning about not being able to perform asymmetric encryption
      Backup::Logger.messages.any? {|msg|
        msg =~ /No recipients available for asymmetric encryption/
      }.should be_true

      # Since there are no other options for encryption,
      # the backup failes with an error.
      Backup::Logger.messages.any? {|msg|
        msg =~ /\[error\]\s+ModelError/
      }.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /\[error\]\s+Reason: Encryptor::GPG::EncryptionError/
      }.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /\[error\]\s+Encryption could not be performed for mode 'asymmetric'/
      }.should be_true

      # Although, any further backup models would be run, as this error
      # is rescued in Backup::Model#perform
      Backup::Logger.messages.any? {|msg|
        msg =~ /Backup will now attempt to continue/
      }.should be_true

      File.exist?(archive_file_for(model)).should be_false
    end
  end # context 'using :asymmetric mode with no valid public keys'

  context 'using :symmetric mode' do
    let(:model) { h_set_trigger('encryptor_gpg_symmetric') }

    it 'should encrypt the archive' do
      model.perform!

      Backup::Logger.has_warnings?.should be_false

      File.exist?(archive_file_for(model)).should be_true

      can_decrypt?(model, 'a secret').should be_true

      # note that without specifying any preferences, the default
      # algorithm used is CAST5
      Backup::Logger.messages.any? {|msg|
        msg =~ /gpg: CAST5 encrypted data/
      }.should be_true
    end
  end # context 'using :symmetric mode'

  # The #gpg_config preferences should also be able to override the algorithm
  # preferences in the recipients' public keys, but the gpg output doesn't
  # give us an easy way to check this. You'd have to inspect the leading bytes
  # of the encrypted file per RFC4880, and I'm not going that far :)
  context 'using :symmetric mode with given gpg_config' do
    let(:model) { h_set_trigger('encryptor_gpg_symmetric_with_config') }

    it 'should encrypt the archive using the proper algorithm preference' do
      model.perform!

      Backup::Logger.has_warnings?.should be_false

      File.exist?(archive_file_for(model)).should be_true

      can_decrypt?(model, 'a secret').should be_true

      # preferences set in #gpg_config specified using AES256 before CAST5
      Backup::Logger.messages.any? {|msg|
        msg =~ /gpg: AES256 encrypted data/
      }.should be_true
    end
  end # context 'using :symmetric mode with given gpg_config'

  context 'using :both mode' do
    let(:model) { h_set_trigger('encryptor_gpg_both') }

    it 'should encrypt the archive' do
      # Preload key for backup01.
      # Key for backup03 will be imported when the model is performed.
      load_gpg_homedir(model.encryptor, :public, :backup01)

      model.perform!

      Backup::Logger.has_warnings?.should be_false

      File.exist?(archive_file_for(model)).should be_true

      # make sure both recipients can decrypt the archive
      [:backup01, :backup03].each do |recipient|
        load_gpg_homedir(model.encryptor, :private, recipient)
        can_decrypt?(model).should be_true
      end

      # with no private keys in the keyring,
      # archive can be decrypted using the passphrase.
      load_gpg_homedir(model.encryptor, :private, nil)
      can_decrypt?(model, 'a secret').should be_true
    end
  end # context 'using :both mode'

  context 'using :both mode with no valid asymmetric recipients' do
    let(:model) { h_set_trigger('encryptor_gpg_both_no_asymmetric') }

    it 'should encrypt the archive using only symmetric encryption' do
      # we'll load backup02, but this isn't one of the :recipients
      load_gpg_homedir(model.encryptor, :public, :backup02)

      model.perform!

      # issues warnings about the missing keys
      Backup::Logger.has_warnings?.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /No public key was found in #keys for '16325C61'/
      }.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /No public key was found in #keys for '<backup03@foo.com>'/
      }.should be_true

      # issues warning about not being able to perform asymmetric encryption
      Backup::Logger.messages.any? {|msg|
        msg =~ /No recipients available for asymmetric encryption/
      }.should be_true

      # backup proceeded, since symmetric encryption could still be performed
      File.exist?(archive_file_for(model)).should be_true

      # with no private keys in the keyring,
      # archive can be decrypted using the passphrase.
      load_gpg_homedir(model.encryptor, :private, nil)
      can_decrypt?(model, 'a secret').should be_true
    end
  end # context 'using :both mode with no valid asymmetric recipients'

  context 'when using the deprecated #key accessor' do
    let(:model) {
      # See notes in spec-live/spec_helper.rb
      h_set_single_model do
        Backup::Model.new(:encryptor_gpg_deprecate_key, 'test_label') do
          archive :test_archive, &Backup::SpecLive::ARCHIVE_JOB
          encrypt_with 'GPG' do |e|
            e.key = Backup::SpecLive::GPGKeys[:backup03][:public]
          end
          store_with 'Local'
        end
      end
    }

    it 'should log a warning and store an encrypted archive' do
      model.perform!

      Backup::Logger.has_warnings?.should be_true
      Backup::Logger.messages.any? {|msg|
        msg =~ /GPG#key has been deprecated/
      }.should be_true

      File.exist?(archive_file_for(model)).should be_true

      load_gpg_homedir(model.encryptor, :private, :backup03)

      can_decrypt?(model).should be_true
    end
  end # context 'when using the deprecated #key accessor'

end
