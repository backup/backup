# encoding: utf-8
require File.expand_path('../../spec_helper.rb', __FILE__)

class Parallel; end

describe Backup::Syncer::CloudFiles do
  describe '#perform!' do
    let(:syncer)     { Backup::Syncer::CloudFiles.new }
    let(:connection) { stub('connection',
      :directories => stub('directories', :get => container)) }
    let(:container)     { stub('container', :files => files) }
    let(:files)      { [] }
    let(:content)    { stub('content') }

    before :each do
      Fog::Storage.stubs(:new).returns connection
      File.stubs(:open).returns content
      File.stubs(:exist?).returns true
      files.stubs(:create).returns true

      syncer.directories << 'tmp'
      syncer.path = 'storage'
      Backup::Syncer::S3::SyncContext.any_instance.
        stubs(:`).returns 'MD5(tmp/foo)= 123abcdef'
    end

    it "respects the concurrency_using setting with threads" do
      syncer.concurrency_using = :threads

      Parallel.expects(:each).with(anything, {:in_threads => 2}, anything)

      syncer.perform!
    end

    it "respects the parallel thread count" do
      syncer.concurrency_using    = :threads
      syncer.concurrency_level = 10

      Parallel.expects(:each).with(anything, {:in_threads => 10}, anything)

      syncer.perform!
    end

    it "respects the concurrency_using setting with processors" do
      syncer.concurrency_using = :processes

      Parallel.expects(:each).with(anything, {:in_processes => 2}, anything)

      syncer.perform!
    end

    it "respects the parallel thread count" do
      syncer.concurrency_using    = :processes
      syncer.concurrency_level = 10

      Parallel.expects(:each).with(anything, {:in_processes => 10}, anything)

      syncer.perform!
    end

    context 'file exists locally' do
      it "uploads a file if it does not exist remotely" do
        files.expects(:create).with(:key => 'storage/tmp/foo', :body => content)

        syncer.perform!
      end

      it "uploads a file if it exists remotely with a different MD5" do
        files << stub('file', :key => 'storage/tmp/foo', :etag => 'abcdef123')

        files.expects(:create).with(:key => 'storage/tmp/foo', :body => content)

        syncer.perform!
      end

      it "does nothing if the file exists remotely with the same MD5" do
        files << stub('file', :key => 'storage/tmp/foo', :etag => '123abcdef')

        files.expects(:create).never

        syncer.perform!
      end

      it "skips the file if it no longer exists locally" do
        File.stubs(:exist?).returns false

        files.expects(:create).never

        syncer.perform!
      end

      it "respects the given path" do
        syncer.path = 'box'

        files.expects(:create).with(:key => 'box/tmp/foo', :body => content)

        syncer.perform!
      end

      it "uploads the content of the local file" do
        File.expects(:open).with('tmp/foo').returns content

        syncer.perform!
      end

      it "creates the connection with the provided credentials" do
        syncer.api_key    = 'my-key'
        syncer.username   = 'my-name'
        syncer.auth_url   = 'my-auth'
        syncer.servicenet = 'my-servicenet'

        Fog::Storage.expects(:new).with(
          :provider             => 'Rackspace',
          :rackspace_api_key    => 'my-key',
          :rackspace_username   => 'my-name',
          :rackspace_auth_url   => 'my-auth',
          :rackspace_servicenet => 'my-servicenet'
        ).returns connection

        syncer.perform!
      end

      it "uses the container with the given name" do
        syncer.container = 'leaky'

        connection.directories.expects(:get).with('leaky').returns(container)

        syncer.perform!
      end

      it "creates the container if one does not exist" do
        syncer.container = 'leaky'
        connection.directories.stubs(:get).returns nil

        connection.directories.expects(:create).
          with(:key => 'leaky').returns(container)

        syncer.perform!
      end

      it "iterates over each directory" do
        syncer.directories << 'files'

        Backup::Syncer::CloudFiles::SyncContext.any_instance.expects(:`).
          with('find tmp -print0 | xargs -0 openssl md5 2> /dev/null').
          returns 'MD5(tmp/foo)= 123abcdef'
        Backup::Syncer::CloudFiles::SyncContext.any_instance.expects(:`).
          with('find files -print0 | xargs -0 openssl md5 2> /dev/null').
          returns 'MD5(tmp/foo)= 123abcdef'

        syncer.perform!
      end
    end

    context 'file does not exist locally' do
      let(:file) { stub('file', :key => 'storage/tmp/foo',
        :etag => '123abcdef') }

      before :each do
        Backup::Syncer::CloudFiles::SyncContext.any_instance.
          stubs(:`).returns ''
        files << file
        File.stubs(:exist?).returns false
      end

      it "removes the remote file when mirroring is turned on" do
        syncer.mirror = true

        file.expects(:destroy).once

        syncer.perform!
      end

      it "leaves the remote file when mirroring is turned off" do
        syncer.mirror = false

        file.expects(:destroy).never

        syncer.perform!
      end

      it "does not remove files not under one of the specified directories" do
        file.stubs(:key).returns 'unsynced/tmp/foo'
        syncer.mirror = true

        file.expects(:destroy).never

        syncer.perform!
      end
    end
  end
end
