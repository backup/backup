---
layout: main
title: Syncer::Cloud::S3 (Core)
---

Syncer::Cloud::S3 (Core feature)
================================

``` rb
sync_with Cloud::S3 do |s3|
  # AWS Credentials
  s3.access_key_id     = "my_access_key_id"
  s3.secret_access_key = "my_secret_access_key"
  # Or, to use a IAM Profile:
  # s3.use_iam_profile = true

  s3.bucket            = "my-bucket"
  s3.region            = "us-east-1"
  s3.path              = "/backups"
  s3.mirror            = true
  s3.thread_count      = 10

  s3.directories do |directory|
    directory.add "/path/to/directory/to/sync"
    directory.add "/path/to/other/directory/to/sync"

    # Exclude files/folders.
    # The pattern may be a shell glob pattern (see `File.fnmatch`) or a Regexp.
    # All patterns will be applied when traversing each added directory.
    directory.exclude '**/*~'
    directory.exclude /\/tmp$/
  end
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

### File Size Limit

The maximum file size that can be transferred is 5 GiB. If a file is encountered that exceeds this limit, it will be
skipped and a warning will be logged. Unlike [Storage::S3][storage-s3], Multipart Uploading is not used.
Keep in mind that if a failure occurs and a retry is attempted, the entire file is re-transmitted.

### Server-Side Encryption

You may configure your AWS S3 stored files to use [Server-Side Encryption][] by adding the following:

```rb
sync_with Cloud::S3 do |s3|
  s3.encryption = :aes256
end
```

[Server-Side Encryption]: http://docs.aws.amazon.com/AmazonS3/latest/dev/UsingServerSideEncryption.html

### Reduced Redundancy Storage

You may configure your AWS S3 stored files to use [Reduced Redundancy Storage][] by adding the following:

```rb
sync_with Cloud::S3 do |s3|
  s3.storage_class = :reduced_redundancy
end
```

[Reduced Redundancy Storage]: http://docs.aws.amazon.com/AmazonS3/latest/dev/UsingRRS.html

### Fog Options

If you need to pass additional options for fog, you can specify those using `fog_options`.

```rb
sync_with Cloud::S3 do |s3|
  s3.fog_options = {
    :path_style => true,
    :persistent => true
    :connection_options => { :tcp_nodelay => true } # these are Excon options
  }
end
```
These options will be merged into those used to establish the connection via fog.  
e.g. `Fog::Storage.new({ :provider => 'AWS'}.merge(fog_options))`

{% include markdown_links %}
