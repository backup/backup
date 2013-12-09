---
layout: main
title: Encryptor::OpenSSL
---

Encryptor::OpenSSL
==================

Create a password-protected backup file with `my_password` as the password.

``` rb
encrypt_with OpenSSL do |encryption|
  encryption.password = 'my_password'
  encryption.base64   = true
  encryption.salt     = true
end
```

Or if you prefer to read the password from a file on the filesystem:

``` rb
encrypt_with OpenSSL do |encryption|
  encryption.password_file = '/path/to/password/file'
  encryption.base64        = true
  encryption.salt          = true
end
```

This will encrypt your backup file using OpenSSL. Ensure OpenSSL is installed on your machine. It usually is by default.
Additional options you can set are the `encryption.base64` and `encryption.salt`, both are booleans. `encryption.base64`
makes encrypted backups readable in text editors, emails, etc. `encryption.salt` (enabled by default) improves the security.
OpenSSL encrypts the backups using the 256bit AES encryption cipher.

### Decrypting OpenSSL

To **decrypt** an OpenSSL encrypted backup file, "Backup" provides a CLI command for doing so.

    $ backup decrypt --encryptor openssl --base64 --salt --password-file <path/to/password/file> \
        --in <encrypted_file> --out <decrypted_file>

If you set the `encryption.base64` to `false`, then don't use the `--base64` flag when decrypting. Once you run this
command you will be prompted for the password you specified in the Backup configuration file. When you fill in the
correct password, the backup file will be decrypted to the location you specified with the `--out` option. You can also
use `--password-file` to provide the password.

{% include markdown_links %}
