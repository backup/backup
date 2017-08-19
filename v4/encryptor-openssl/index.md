---
layout: main
title: Encryptor::OpenSSL (Core)
---

Encryptor::OpenSSL (Core feature)
=================================

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

### Decrypting

To decrypt your backup, use the following command:

    $ openssl aes-256-cbc -d -base64 -in my_backup.tar.enc -out my_backup.tar

`-base64` is only required if you used `encryption.base64 = true`.

You will be prompted for your password.


{% include markdown_links %}
