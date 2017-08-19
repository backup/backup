---
layout: main
title: Storage::CloudFiles (Extra)
---

Storage::CloudFiles (Extra)
===========================

You will need a Rackspace Cloud Files account. You can get one [here](http://www.rackspace.com/cloud/).

```rb
store_with CloudFiles do |cf|
  cf.api_key            = 'my_api_key'
  cf.username           = 'my_username'
  cf.container          = 'my_container'
  cf.segments_container = 'my_segments_container' # must be different than `container`
  cf.segment_size       = 5 # MiB
  cf.path               = 'path/to/backups' # path within the container
end
```

### Endpoints and Regions

By default, the US endpoint `identity.api.rackspacecloud.com/v2.0` will be used.
If you need to use another endpoint, specify the `auth_url`:

```rb
store_with CloudFiles do |cf|
  cf.auth_url = 'lon.identity.api.rackspacecloud.com/v2.0'
end
```

The default region is `:dfw` (Dallas). You may specify another region using:

```rb
store_with CloudFiles do |cf|
  cf.region = :ord # Chicago
end
```

If Backup is running on a Rackspace Cloud Server in the same data center as your Cloud Files server,
you can enable the use of Rackspace's ServiceNet to avoid bandwidth charges by setting:

```rb
store_with CloudFiles do |cf|
  cf.servicenet = true
end
```

### Static Large Object Support

When backup package files are stored, each file that is larger than `segment_size` will be created
as a Static Large Object (SLO). Segments of `segment_size` are uploaded into your `segments_container`,
then a SLO Manifest object is uploaded into your `container` which references all of it's associated segments.
To retrieve your backup, you only have to download the files within your `container`.
The segments are automatically streamed to you by the server when you download the SLO Manifest object.

A SLO may have a maximum of 1,000 segments. If you use 5 MiB as your `segment_size`, then the maximum size
of this object would be close to 5 GiB (1024^2 x 5 x 1000 = 5,242,880,000 bytes). If your final backup package
is larger than this, Backup will automatically adjust your `segment_size` to fit the object within the 1,000
segment limit _and log a warning_.

To control the `segment_size` while allowing for larger backups, you should use the [Splitter][splitter] to split your
final backup package into files based on your `segment_size`. If your `segment_size` is 5 MiB, then you would
configure the Splitter with `split_into_chunks_of 5000` (segment_size x 1,000).

Each segment is uploaded using _chunked transfer encoding_ with a 1 MiB buffer, so `segment_size` will not affect
memory usage. However, `segment_size` is the amount of data that will be re-transmitted should an error occur.
Therefore, it's best to keep the `segment_size` low.


### Cycling Backups

Backup's [Cycler][storages] may be used to keep a specified number of backups in storage.
After each backup is performed, it will remove older backup package files based on the `keep` setting.

You may alternately use the `days_to_keep` setting to schedule your backup to removed after the specified
number of days by the Rackspace Cloud Files server.

```rb
store_with CloudFiles do |cf|
  cf.days_to_keep = 90
end
```

If you are transitioning from using `keep` to `days_to_keep`, you should leave your `keep` setting configured until all
previous backups that were stored using `keep` are removed by the Cycler. As long as `keep` is configured, all backups
performed while `days_to_keep` is also configured will be tracked by the Cycler. These backups will count towards the
number of backups stored so the Cycler knows when to remove those stored prior to using `days_to_keep`. The Cycler will
not attempt to remove any backup that was stored with `days_to_keep` set.


### Error Handling

Each request involved in transmitting your package files will be retried if an error occurs. By default, each failed
request will be retried 10 times, pausing 30 seconds before each retry. These defaults may be changed using:

```rb
store_with CloudFiles do |cf|
  cf.max_retries = 10
  cf.retry_waitsec = 30
end
```
When an error occurs that causes Backup to retry the request, the error will be logged. Note that these messages
will be logged as _informational_ messages, so they will not generate warnings.

If the request being retried was a failed request to upload a SLO segment, only that `segment_size` of the package
file being uploaded will be re-transmitted.


### Data Integrity

All data is uploaded along with a MD5 checksum which Cloud Files uses to verify the data received. If the data uploaded
fails this integrity check, the error will be handled as stated above and the data will be retransmitted.

### Fog Options

If you need to pass additional options for fog, you can specify those using `fog_options`.

```rb
store_with CloudFiles do |cf|
  cf.fog_options = {
    :persistent => true,
    :connection_options => { :nonblock => false } # these are Excon options
  }
end
```
These options will be merged into those used to establish the connection via fog.  
e.g. `Fog::Storage.new({ :provider => 'Rackspace'}.merge(fog_options))`

{% include markdown_links %}
