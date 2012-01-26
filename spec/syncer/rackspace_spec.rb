# encoding: utf-8
require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Syncer::Rackspace do
  describe '#perform!' do
    let(:syncer)     { Backup::Syncer::Rackspace.new }
    let(:connection) { stub('connection',
      :directories => stub('directories', :get => bucket)) }
    let(:bucket)     { stub('bucket', :files => files) }
    let(:files)      { [] }
    let(:content)    { stub('content') }

    before :each do
      Fog::Storage.stubs(:new).returns connection
      File.stubs(:open).returns content
      File.stubs(:exist?).returns true
      files.stubs(:create).returns true

      syncer.directories << 'tmp'
      syncer.path = 'storage'
    end

    context 'file exists locally' do
      before :each do
        syncer.stubs(:`).returns 'MD5(tmp/foo)= 123abcdef'
      end

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
        syncer.api_key  = 'my-key'
        syncer.username = 'my-name'
        syncer.auth_url = 'my-auth'

        Fog::Storage.expects(:new).with(
          :provider           => 'Rackspace',
          :rackspace_api_key  => 'my-key',
          :rackspace_username => 'my-name',
          :rackspace_auth_url => 'my-auth'
        ).returns connection

        syncer.perform!
      end

      it "uses the bucket with the given name" do
        syncer.bucket = 'leaky'

        connection.directories.expects(:get).with('leaky').returns(bucket)

        syncer.perform!
      end

      it "creates the bucket if one does not exist" do
        syncer.bucket = 'leaky'
        connection.directories.stubs(:get).returns nil

        connection.directories.expects(:create).
          with(:key => 'leaky').returns(bucket)

        syncer.perform!
      end

      it "iterates over each directory" do
        syncer.directories << 'files'

        syncer.expects(:`).
          with('find tmp -print0 | xargs -0 openssl md5 2> /dev/null').
          returns 'MD5(tmp/foo)= 123abcdef'
        syncer.expects(:`).
          with('find files -print0 | xargs -0 openssl md5 2> /dev/null').
          returns 'MD5(tmp/foo)= 123abcdef'

        syncer.perform!
      end
    end
  end
end
