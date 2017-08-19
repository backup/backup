---
layout: main
title: Encryptors
---

Encryptors
==========

Backup includes the following Encryptors:

- [GPG][encryptor-gpg] (Core)
- [OpenSSL][encryptor-openssl] (Core)

Only one Encryptor may be configured for each Model.

Once all [Archives][archives] and [Databases][databases] have been processed, Backup will package these into a single
`tar` file. If an Encryptor is configured, this final backup package will be piped through the encryption utility.

Note that if the [Splitter][splitter] is used, the final backup package is encrypted _before_ it is split.


{% include markdown_links %}
