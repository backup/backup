---
layout: main
title: Encryptor::GPG (Core)
---

Encryptor::GPG (Core feature)
=============================

To use GPG you need to have a GPG encryption (public, private) key pair.

To generate a new GPG key to use with the Backup gem, issue the following command:

    $ gpg --gen-key

And follow the instructions. Usually the defaults are fine.
Once the keys have been generated you may issue the following commands to confirm they were successfully created.

    $ gpg --list-keys
    $ gpg --list-secret-keys

If you see your keys in the list, it means it successfully generated the keys.
Be sure to store your private key in a safe place, otherwise you will not be able to decrypt your backups.

Now, in order to get the long (public) key which you need to paste in to the Backup configuration file,
issue the following command:

    $ gpg -a --export [EMAIL]

`EMAIL` being the email you specified when generating the keys.

Now copy/paste the key into the Backup configuration file, making sure to assign the key to the email address
you used to create the key, and specify that email address as the recipient.

``` rb
encrypt_with GPG do |encryption|
  encryption.keys = {}
  encryption.keys['joe@example.com'] = <<-KEY
    -----BEGIN PGP PUBLIC KEY BLOCK-----
    Version: GnuPG v1.4.11 (Darwin)

        [ Your GPG Public Key Here ]
    -----END PGP PUBLIC KEY BLOCK-----
  KEY
  encryption.recipients = 'joe@example.com'
end
```

The above is a simple example of using the GPG Encryptor to asymmetrically encrypt your backup using a single
GPG public/private keypair. However, it also supports multiple recipients, as well as symmetric encryption or a
combination of both. For example, the following backup could be decrypted using either user's private key or the passphrase:

``` rb
encrypt_with GPG do |encryption|
  encryption.keys = {}
  encryption.keys['joe@example.com'] = <<-KEY
    -----BEGIN PGP PUBLIC KEY BLOCK-----
    Version: GnuPG v1.4.11 (Darwin)

        [ Joe's GPG Public Key Here ]
    -----END PGP PUBLIC KEY BLOCK-----
  KEY
  encryption.keys['mary@example.com'] = <<-KEY
    -----BEGIN PGP PUBLIC KEY BLOCK-----
    Version: GnuPG v1.4.11 (Darwin)

        [ Mary's GPG Public Key Here ]
    -----END PGP PUBLIC KEY BLOCK-----
  KEY
  encryption.recipients = ['joe@example.com', 'mary@example.com']
  encryption.passphrase = 'secret passphrase'
  encryption.mode = :both
end
```

Other advanced options are also available. For more detailed instructions, see the documentation
in `lib/backup/encryptor/gpg.rb` or online at [rubydoc.info](http://rubydoc.info/gems/backup/Backup/Encryptor/GPG).

**NOTE:** The GPG Encryptor requires `gpg`, **not** `gpg2`.


### Decrypting

To decrypt your backup, use the following command:

    $ gpg -o my_backup.tar -d my_backup.tar.gpg

This will require the _private_ key or password needed.


Default Configuration
---------------------

If you are planning to encrypt multiple backups, especially with GPG, your configuration file may become extremely
verbose and long. If you are using the same GPG key(s) to encrypt multiple backups, it is a good idea to setup all the
GPG keys you will be using in Backup's default configuration.

``` rb
Encryptor::GPG.defaults do |encryption|
  encryption.keys = {}

  encryption.keys['joe@example.com'] = <<-KEY
    -----BEGIN PGP PUBLIC KEY BLOCK-----
    Version: GnuPG v1.4.11 (Darwin)

    [ Joe's GPG Public Key Here ]
    -----END PGP PUBLIC KEY BLOCK-----
  KEY

  encryption.keys['mary@example.com'] = <<-KEY
    -----BEGIN PGP PUBLIC KEY BLOCK-----
    Version: GnuPG v1.4.12 (GNU/Linux)

    [ Mary's GPG Public Key Here ]
    -----END PGP PUBLIC KEY BLOCK-----
  KEY

  # Specify the default recipients for all backups (optional)
  encryption.recipients = ['joe@example.com', 'mary@example.com']
end
```

So now, every time you wish to encrypt a backup with GPG and the above GPG keys,
all you have to add in to your configuration file is the following:

``` rb
encrypt_with GPG
```

Or, you can override the default recipients to use specific GPG keys:

```rb
encrypt_with GPG do |encryption|
  encryption.recipients = 'mary@example.com'

  # To add recipients to defaults, set your defaults as an Array:
  #   encryption.recipients = ['admin@example.com']
  # Then use:
  #   encryption.recipients += ['mary@example.com', 'support@email.com']

end
```

{% include markdown_links %}
