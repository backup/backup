---
layout: main
title: Syncer::Cloud::CloudFiles (Extra)
---

Syncer::Cloud::CloudFiles (Extra)
=================================

``` rb
sync_with Cloud::CloudFiles do |cf|
  cf.username          = "my_username"
  cf.api_key           = "my_api_key"
  cf.container         = "my_container"
  cf.path              = "/backups"
  cf.mirror            = true
  cf.thread_count      = 10

  cf.directories do |directory|
    directory.add "/path/to/directory/to/sync"
    directory.add "/path/to/other/directory/to/sync"

    # Exclude files/folders from the sync.
    # The pattern may be a shell glob pattern (see `File.fnmatch`) or a Regexp.
    # All patterns will be applied when traversing each added directory.
    directory.exclude '**/*~'
    directory.exclude /\/tmp$/
  end
end
```

### File Size Limit

The maximum file size that can be transferred is 5 GiB. If a file is encountered that exceeds this limit, it will be
skipped and a warning will be logged. Unlike [Storage::CloudFiles][storage-cloudfiles], SLO support is not available.
Keep in mind that if a failure occurs and a retry is attempted, the entire file is re-transmitted.


### Endpoints and Regions

By default, the US endpoint `identity.api.rackspacecloud.com/v2.0` will be used.
If you need to use another endpoint, specify the `auth_url`:

```rb
sync_with Cloud::CloudFiles do |cf|
  cf.auth_url = 'lon.identity.api.rackspacecloud.com/v2.0'
end
```

The default region is `:dfw` (Dallas). You may specify another region using:

```rb
sync_with Cloud::CloudFiles do |cf|
  cf.region = :ord # Chicago
end
```

If Backup is running on a Rackspace Cloud Server in the same data center as your Cloud Files server,
you can enable the use of Rackspace's ServiceNet to avoid bandwidth charges by setting:

```rb
sync_with Cloud::CloudFiles do |cf|
  cf.servicenet = true
end
```

### Fog Options

If you need to pass additional options for fog, you can specify those using `fog_options`.

```rb
sync_with Cloud::CloudFiles do |cf|
  cf.fog_options = {
    :persistent => true
    :connection_options => { :tcp_nodelay => true } # these are Excon options
  }
end
```
These options will be merged into those used to establish the connection via fog.  
e.g. `Fog::Storage.new({ :provider => 'Rackspace'}.merge(fog_options))`

{% include markdown_links %}
