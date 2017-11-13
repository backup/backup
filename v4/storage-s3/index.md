---
layout: main
title: Storage::S3 (Core)
---

Storage::S3 (Core feature)
==========================

You will need an Amazon AWS (S3) account. You can get one [here](http://aws.amazon.com/s3/).

``` rb
store_with S3 do |s3|
  # AWS Credentials
  s3.access_key_id     = "my_access_key_id"
  s3.secret_access_key = "my_secret_access_key"
  # Or, to use a IAM Profile:
  # s3.use_iam_profile = true

  s3.region             = 'us-east-1'
  s3.bucket             = 'bucket-name'
  s3.path               = 'path/to/backups'
end
```

### [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region)

* `us-east-1` - US Standard (Default)
* `us-west-2` - US West (Oregon)
* `us-west-1` - US West (Northern California)
* `eu-west-1` - EU (Ireland)
* `ap-southeast-1` - Asia Pacific (Singapore)
* `ap-southeast-2` - Asia Pacific (Sydney)
* `ap-northeast-1` - Asia Pacific (Tokyo)
* `sa-east-1` - South America (Sao Paulo)
* `cn-north-1` - China North 1 - see [this section](#china-region) for support.

### Multipart Uploading

Amazon's [Multipart Uploading][] will be used to upload each of your final package files which are larger than the
default `chunk_size` of 5 MiB. Each package file less than or equal to the `chunk_size` will be uploaded using a single
request. This may be changed using:

```rb
store_with S3 do |s3|
  # Minimum allowed setting is 5.
  s3.chunk_size = 10 # MiB
end
```

Each file uploaded using Multipart Uploading can consist of up to 10,000 chunks. If the file being uploaded is too
large to be divided into 10,000 chunks at the configured `chunk_size`, the `chunk_size` will be automatically
adjusted and a warning will be logged. To enforce your desired `chunk_size`, you should use the [Splitter][splitter].

For example, with the default `chunk_size` of 5 MiB, the maximum file size would be 5 MiB * 10,000 (52,428,800,000 -
or ~48.5 GiB). If your final backup package might be larger than this, you should configure the Splitter to
`split_into_chunks_of 50_000` (chunk_size x 10,000).

The maximum `chunk_size` is 5120 (5 GiB), but it's best to keep this small. First, this is the amount of data that will be
retransmitted should a failure occur. Second, each `chunk_size` of data must be read into memory when uploading the chunk.


### Error Handling

Each request involved in transmitting your package files will be retried if an error occurs. By default, each failed
request will be retried 10 times, pausing 30 seconds before each retry. These defaults may be changed using:

```rb
store_with S3 do |s3|
  s3.max_retries = 10
  s3.retry_waitsec = 30
end
```

If the request being retried was a failed request to upload a `chunk_size` portion of the file being uploaded,
only that `chunk_size` portion will be re-transmitted. For files less than `chunk_size` in size, the whole file upload
will be attempted again. For this reason, it's best not to set `chunk_size` too high.

When an error occurs that causes Backup to retry the request, the error will be logged. Note that these messages
will be logged as _informational_ messages, so they will not generate warnings.

### Data Integrity

All data is uploaded along with a MD5 checksum which AWS uses to verify the data received. If the data uploaded fails
this integrity check, the error will be handled as stated above and the data will be retransmitted.

### Server-Side Encryption

You may configure your AWS S3 stored files to use [Server-Side Encryption][] by adding the following:

```rb
store_with S3 do |s3|
  s3.encryption = :aes256
end
```

### Storage types

#### Reduced Redundancy Storage

You may configure your AWS S3 stored files to use [Reduced Redundancy Storage][] by adding the following:

```rb
store_with S3 do |s3|
  s3.storage_class = :reduced_redundancy
end
```

#### Infrequent Access Storage

You may configure your AWS S3 stored files to use [Infrequent Access Storage][] by adding the following:

```rb
store_with S3 do |s3|
  s3.storage_class = :standard_ia
end
```

#### Amazon Glacier

Backup does not have direct Amazon Glacier support. However, using AWS [Object Lifecycle Management][],
you can setup rules to [transition objects to Glacier][]. A major benefit of this is that these these backups
can be [restored using the S3 console][].

### Cycling Backups

Backup's [Cycler][storages] may be used to keep a specified number of backups in storage.
After each backup is performed, it will remove older backup package files based on the `keep` setting.

However, you may want to consider using AWS [Object Lifecycle Management][] to [automatically remove][]
your backups after a specified period of time. This may also be used in conjunction with Amazon Glacier,
so you could transition backups to Glacier after a period of time, then have them automatically removed
at a later date.

### Fog Options

If you need to pass additional options for fog, you can specify those using `fog_options`.

```rb
store_with S3 do |s3|
  s3.fog_options = {
    :path_style => true,
    :connection_options => { :nonblock => false } # these are Excon options
  }
end
```
These options will be merged into those used to establish the connection via fog.  
e.g. `Fog::Storage.new({ :provider => 'AWS'}.merge(fog_options))`

### S3-Compatible APIs

Fog allows Backup to be used with additional S3-interoperable object storage
APIs like [DigitalOcean's Spaces] or [Minio] through additional configuration of
`fog_options`. Depending on the service's level of compatibility, it is generally
enough to define the `endpoint`. For example, the following configuration can
be used to back up to Spaces:

```rb
store_with S3 do |s3|
  s3.access_key_id     = "my_access_key_id"
  s3.secret_access_key = "my_secret_access_key"
  s3.region            = "nyc3"
  s3.bucket            = "bucket-name"
  s3.path              = "path/to/backups"
  s3.fog_options       = {
    endpoint: "https://nyc3.digitaloceanspaces.com",
    aws_signature_version: 2
  }
end
```

### China region

Backup relies on [fog][] for AWS S3 support. Fog does not support the China region directly.

A workaround is the following config, as seen in [issue #791][].

```rb
store_with S3 do |s3|
  # ... your config

  s3.region = "cn-north-1"
  s3.fog_options = { endpoint: "https://s3.cn-north-1.amazonaws.com.cn" }
end
```

[Multipart Uploading]:            http://docs.aws.amazon.com/AmazonS3/latest/dev/mpuoverview.html
[Server-Side Encryption]:         http://docs.aws.amazon.com/AmazonS3/latest/dev/UsingServerSideEncryption.html
[Infrequent Access Storage]:      http://docs.aws.amazon.com/AmazonS3/latest/dev/storage-class-intro.html
[Reduced Redundancy Storage]:     http://docs.aws.amazon.com/AmazonS3/latest/dev/Introduction.html#RRS
[Object Lifecycle Management]:    http://docs.aws.amazon.com/AmazonS3/latest/dev/object-lifecycle-mgmt.html
[transition objects to Glacier]:  http://docs.aws.amazon.com/AmazonS3/latest/dev/object-archival.html
[restored using the S3 console]:  http://docs.aws.amazon.com/AmazonS3/latest/dev/restoring-objects-console.html
[automatically remove]:           http://docs.aws.amazon.com/AmazonS3/latest/dev/ObjectExpiration.html
[DigitalOcean's Spaces]:          https://developers.digitalocean.com/documentation/v2/
[Minio]:                          https://www.minio.io/
[fog]:                            https://github.com/fog/fog-aws/
[issue #791]:                      https://github.com/backup/backup/issues/791#issuecomment-239059386

{% include markdown_links %}
