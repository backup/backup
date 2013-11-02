# encoding: utf-8
require File.expand_path('../../spec_helper.rb', __FILE__)
require 'backup/cloud_io/cloud_files'

module Backup
describe CloudIO::CloudFiles do
  let(:connection) { mock }

  describe '#upload' do
    before do
      described_class.any_instance.expects(:create_containers)
    end

    context 'with SLO support' do
      let(:cloud_io) {
        CloudIO::CloudFiles.new(
          :container          => 'my_container',
          :segments_container => 'my_segments_container',
          :segment_size       => 5
        )
      }
      let(:segments) { mock }

      context 'when src file is larger than segment_size' do
        before do
          File.expects(:size).with('/src/file').returns(10 * 1024**2)
        end

        it 'uploads as a SLO' do
          cloud_io.expects(:upload_segments).with(
            '/src/file', 'dest/file', 5 * 1024**2, 10 * 1024**2
          ).returns(segments)
          cloud_io.expects(:upload_manifest).with('dest/file', segments)
          cloud_io.expects(:put_object).never

          cloud_io.upload('/src/file', 'dest/file')
        end
      end

      context 'when src file is not larger than segment_size' do
        before do
          File.expects(:size).with('/src/file').returns(5 * 1024**2)
        end

        it 'uploads as a non-SLO' do
          cloud_io.expects(:put_object).with('/src/file', 'dest/file')
          cloud_io.expects(:upload_segments).never
          cloud_io.expects(:upload_manifest).never

          cloud_io.upload('/src/file', 'dest/file')
        end
      end

      context 'when segment_size is too small for the src file' do
        before do
          File.expects(:size).with('/src/file').returns((5000 * 1024**2) + 1)
        end

        it 'warns and adjusts the segment_size' do
          cloud_io.expects(:upload_segments).with(
            '/src/file', 'dest/file', 6 * 1024**2, (5000 * 1024**2) + 1
          ).returns(segments)
          cloud_io.expects(:upload_manifest).with('dest/file', segments)
          cloud_io.expects(:put_object).never

          Logger.expects(:warn).with do |err|
            expect( err.message ).to include(
              "#segment_size of 5 MiB has been adjusted\n  to 6 MiB"
            )
          end

          cloud_io.upload('/src/file', 'dest/file')
        end
      end

      context 'when src file is too large' do
        before do
          File.expects(:size).with('/src/file').
              returns(described_class::MAX_SLO_SIZE + 1)
        end

        it 'raises an error' do
          cloud_io.expects(:upload_segments).never
          cloud_io.expects(:upload_manifest).never
          cloud_io.expects(:put_object).never

          expect do
            cloud_io.upload('/src/file', 'dest/file')
          end.to raise_error(CloudIO::FileSizeError)
        end
      end

    end # context 'with SLO support'

    context 'without SLO support' do
      let(:cloud_io) {
        CloudIO::CloudFiles.new(
          :container          => 'my_container',
          :segment_size       => 0
        )
      }

      before do
        cloud_io.expects(:upload_segments).never
      end

      context 'when src file size is ok' do
        before do
          File.expects(:size).with('/src/file').
              returns(described_class::MAX_FILE_SIZE)
        end

        it 'uploads as non-SLO' do
          cloud_io.expects(:put_object).with('/src/file', 'dest/file')

          cloud_io.upload('/src/file', 'dest/file')
        end
      end

      context 'when src file is too large' do
        before do
          File.expects(:size).with('/src/file').
              returns(described_class::MAX_FILE_SIZE + 1)
        end

        it 'raises an error' do
          cloud_io.expects(:put_object).never

          expect do
            cloud_io.upload('/src/file', 'dest/file')
          end.to raise_error(CloudIO::FileSizeError)
        end
      end

    end # context 'without SLO support'

  end # describe '#upload'

  describe '#objects' do
    let(:cloud_io) {
      CloudIO::CloudFiles.new(
        :container => 'my_container',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }

    before do
      cloud_io.stubs(:connection).returns(connection)
      cloud_io.expects(:create_containers)
    end

    it 'ensures prefix ends with /' do
      connection.expects(:get_container).
          with('my_container', { :prefix => 'foo/bar/' }).
          returns(stub(:body => []))
      expect( cloud_io.objects('foo/bar') ).to eq []
    end

    it 'returns an empty array when no objects are found' do
      connection.expects(:get_container).
          with('my_container', { :prefix => 'foo/bar/' }).
          returns(stub(:body => []))
      expect( cloud_io.objects('foo/bar/') ).to eq []
    end

    context 'when less than 10,000 objects are available' do
      let(:resp_body) {
        10.times.map {|n| { 'name' => "name_#{ n }", 'hash' => "hash_#{ n }" } }
      }

      it 'returns all objects' do
        cloud_io.expects(:with_retries).
            with("GET 'my_container/foo/bar/*'").yields
        connection.expects(:get_container).
            with('my_container', { :prefix => 'foo/bar/' }).
            returns(stub(:body => resp_body))

        objects = cloud_io.objects('foo/bar/')
        expect( objects.count ).to be 10
        objects.each_with_index do |object, n|
          expect( object.name ).to eq("name_#{ n }")
          expect( object.hash ).to eq("hash_#{ n }")
        end
      end
    end

    context 'when more than 10,000 objects are available' do
      let(:resp_body_a) {
        10000.times.map {|n| { 'name' => "name_#{ n }", 'hash' => "hash_#{ n }" } }
      }
      let(:resp_body_b) {
        10.times.map {|n|
          n += 10000
          { 'name' => "name_#{ n }", 'hash' => "hash_#{ n }" }
        }
      }

      it 'returns all objects' do
        cloud_io.expects(:with_retries).twice.
            with("GET 'my_container/foo/bar/*'").yields
        connection.expects(:get_container).
            with('my_container', { :prefix => 'foo/bar/' }).
            returns(stub(:body => resp_body_a))
        connection.expects(:get_container).
            with('my_container', { :prefix => 'foo/bar/', :marker => 'name_9999' }).
            returns(stub(:body => resp_body_b))

        objects = cloud_io.objects('foo/bar/')
        expect( objects.count ).to be 10010
      end

      it 'retries on errors' do
        connection.expects(:get_container).twice.
            with('my_container', { :prefix => 'foo/bar/' }).
            raises('error').then.
            returns(stub(:body => resp_body_a))
        connection.expects(:get_container).twice.
            with('my_container', { :prefix => 'foo/bar/', :marker => 'name_9999' }).
            raises('error').then.
            returns(stub(:body => resp_body_b))

        objects = cloud_io.objects('foo/bar/')
        expect( objects.count ).to be 10010
      end

    end

  end # describe '#objects'

  describe '#head_object' do
    let(:cloud_io) {
      CloudIO::CloudFiles.new(
        :container => 'my_container',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }

    before do
      cloud_io.stubs(:connection).returns(connection)
    end

    it 'returns head_object response with retries' do
      object = stub(:name => 'obj_name')
      connection.expects(:head_object).twice.
          with('my_container', 'obj_name').
          raises('error').then.returns(:response)
      expect( cloud_io.head_object(object) ).to eq :response
    end
  end # describe '#head_object'

  describe '#delete' do
    let(:cloud_io) {
      CloudIO::CloudFiles.new(
        :container => 'my_container',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }
    let(:resp_ok) { stub(:body => { 'Response Status' => '200 OK' }) }
    let(:resp_bad) { stub(:body => { 'Response Status' => '400 Bad Request' }) }

    before do
      cloud_io.stubs(:connection).returns(connection)
    end

    it 'accepts a single Object' do
      object = described_class::Object.new(
        :foo, { 'name' => 'obj_name', 'hash' => 'obj_hash' }
      )
      cloud_io.expects(:with_retries).with('DELETE Multiple Objects').yields
      connection.expects(:delete_multiple_objects).
          with('my_container', ['obj_name']).returns(resp_ok)
      cloud_io.delete(object)
    end

    it 'accepts a multiple Objects' do
      object_a = described_class::Object.new(
        :foo, { 'name' => 'obj_a_name', 'hash' => 'obj_a_hash' }
      )
      object_b = described_class::Object.new(
        :foo, { 'name' => 'obj_b_name', 'hash' => 'obj_b_hash' }
      )
      cloud_io.expects(:with_retries).with('DELETE Multiple Objects').yields
      connection.expects(:delete_multiple_objects).
          with('my_container', ['obj_a_name', 'obj_b_name']).returns(resp_ok)

      objects = [object_a, object_b]
      expect do
        cloud_io.delete(objects)
      end.not_to change { objects }
    end

    it 'accepts a single name' do
      cloud_io.expects(:with_retries).with('DELETE Multiple Objects').yields
      connection.expects(:delete_multiple_objects).
          with('my_container', ['obj_name']).returns(resp_ok)
      cloud_io.delete('obj_name')
    end

    it 'accepts multiple names' do
      cloud_io.expects(:with_retries).with('DELETE Multiple Objects').yields
      connection.expects(:delete_multiple_objects).
          with('my_container', ['obj_a_name', 'obj_b_name']).returns(resp_ok)

      names = ['obj_a_name', 'obj_b_name']
      expect do
        cloud_io.delete(names)
      end.not_to change { names }
    end

    it 'does nothing if empty array passed' do
      connection.expects(:delete_multiple_objects).never
      cloud_io.delete([])
    end

    it 'deletes 10,000 objects per request' do
      names_10k = 10000.times.map { 'name' }
      names_10 = 10.times.map { 'name' }
      names_all = names_10k + names_10

      cloud_io.expects(:with_retries).twice.with('DELETE Multiple Objects').yields
      connection.expects(:delete_multiple_objects).
          with('my_container', names_10k).returns(resp_ok)
      connection.expects(:delete_multiple_objects).
          with('my_container', names_10).returns(resp_ok)

      expect do
        cloud_io.delete(names_all)
      end.not_to change { names_all }
    end

    it 'retries on raised errors' do
      connection.expects(:delete_multiple_objects).twice.
          with('my_container', ['obj_name']).
          raises('error').then.returns(resp_ok)
      cloud_io.delete('obj_name')
    end

    it 'retries on returned errors' do
      connection.expects(:delete_multiple_objects).twice.
          with('my_container', ['obj_name']).
          returns(resp_bad).then.returns(resp_ok)
      cloud_io.delete('obj_name')
    end

    it 'fails after retries exceeded' do
      connection.expects(:delete_multiple_objects).twice.
          with('my_container', ['obj_name']).
          raises('error message').then.returns(resp_bad)

      expect do
        cloud_io.delete('obj_name')
      end.to raise_error(CloudIO::Error) {|err|
        expect( err.message ).to eq(
          "CloudIO::Error: Max Retries (1) Exceeded!\n" +
          "  Operation: DELETE Multiple Objects\n" +
          "  Be sure to check the log messages for each retry attempt.\n" +
          "--- Wrapped Exception ---\n" +
          "CloudIO::CloudFiles::Error: 400 Bad Request\n" +
          "  The server returned the following:\n" +
          "  {\"Response Status\"=>\"400 Bad Request\"}"
        )
      }
      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "CloudIO::Error: Retry #1 of 1\n" +
        "  Operation: DELETE Multiple Objects\n" +
        "--- Wrapped Exception ---\n" +
        "RuntimeError: error message"
      )
    end

  end # describe '#delete'

  describe '#delete_slo' do
    let(:cloud_io) {
      CloudIO::CloudFiles.new(
        :container => 'my_container',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }
    let(:object_a) {
      described_class::Object.new(
        :foo, { 'name' => 'obj_a_name', 'hash' => 'obj_a_hash' }
      )
    }
    let(:object_b) {
      described_class::Object.new(
        :foo, { 'name' => 'obj_b_name', 'hash' => 'obj_b_hash' }
      )
    }
    let(:resp_ok) { stub(:body => { 'Response Status' => '200 OK' }) }
    let(:resp_bad) { stub(:body => { 'Response Status' => '400 Bad Request' }) }

    before do
      cloud_io.stubs(:connection).returns(connection)
    end

    it 'deletes a single SLO' do
      connection.expects(:delete_static_large_object).
          with('my_container', 'obj_a_name').returns(resp_ok)
      cloud_io.delete_slo(object_a)
    end

    it 'deletes a multiple SLOs' do
      connection.expects(:delete_static_large_object).
          with('my_container', 'obj_a_name').returns(resp_ok)
      connection.expects(:delete_static_large_object).
          with('my_container', 'obj_b_name').returns(resp_ok)
      cloud_io.delete_slo([object_a, object_b])
    end

    it 'retries on raised and returned errors' do
      connection.expects(:delete_static_large_object).twice.
          with('my_container', 'obj_a_name').
          raises('error').then.returns(resp_ok)
      connection.expects(:delete_static_large_object).twice.
          with('my_container', 'obj_b_name').
          returns(resp_bad).then.returns(resp_ok)
      cloud_io.delete_slo([object_a, object_b])
    end

    it 'fails after retries exceeded' do
      connection.expects(:delete_static_large_object).twice.
          with('my_container', 'obj_a_name').
          raises('error message').then.returns(resp_ok)
      connection.expects(:delete_static_large_object).twice.
          with('my_container', 'obj_b_name').
          returns(resp_bad).then.raises('failure')

      expect do
        cloud_io.delete_slo([object_a, object_b])
      end.to raise_error(CloudIO::Error) {|err|
        expect( err.message ).to eq(
          "CloudIO::Error: Max Retries (1) Exceeded!\n" +
          "  Operation: DELETE SLO Manifest 'my_container/obj_b_name'\n" +
          "  Be sure to check the log messages for each retry attempt.\n" +
          "--- Wrapped Exception ---\n" +
          "RuntimeError: failure"
        )
      }
      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "CloudIO::Error: Retry #1 of 1\n" +
        "  Operation: DELETE SLO Manifest 'my_container/obj_a_name'\n" +
        "--- Wrapped Exception ---\n" +
        "RuntimeError: error message\n" +
        "CloudIO::Error: Retry #1 of 1\n" +
        "  Operation: DELETE SLO Manifest 'my_container/obj_b_name'\n" +
        "--- Wrapped Exception ---\n" +
        "CloudIO::CloudFiles::Error: 400 Bad Request\n" +
        "  The server returned the following:\n" +
        "  {\"Response Status\"=>\"400 Bad Request\"}"
      )
    end

  end #describe '#delete_slo'

  describe '#connection' do
    let(:cloud_io) {
      CloudIO::CloudFiles.new(
        :username   => 'my_username',
        :api_key    => 'my_api_key',
        :auth_url   => 'my_auth_url',
        :region     => 'my_region',
        :servicenet => false
      )
    }

    it 'caches a connection' do
      Fog::Storage.expects(:new).once.with(
        :provider             => 'Rackspace',
        :rackspace_username   => 'my_username',
        :rackspace_api_key    => 'my_api_key',
        :rackspace_auth_url   => 'my_auth_url',
        :rackspace_region     => 'my_region',
        :rackspace_servicenet => false
      ).returns(connection)

      expect( cloud_io.send(:connection) ).to be connection
      expect( cloud_io.send(:connection) ).to be connection
    end

    it 'passes along fog_options' do
      Fog::Storage.expects(:new).with({
          :provider => 'Rackspace',
          :rackspace_username   => 'my_user',
          :rackspace_api_key    => 'my_key',
          :rackspace_auth_url   => nil,
          :rackspace_region     => nil,
          :rackspace_servicenet => nil,
          :connection_options => { :opt_key => 'opt_value' },
          :my_key => 'my_value'
      })
      CloudIO::CloudFiles.new(
        :username   => 'my_user',
        :api_key    => 'my_key',
        :fog_options => {
          :connection_options => { :opt_key => 'opt_value' },
          :my_key => 'my_value'
        }
      ).send(:connection)
    end

  end # describe '#connection'

  describe '#create_containers' do

    context 'with SLO support' do
      let(:cloud_io) {
        CloudIO::CloudFiles.new(
          :container => 'my_container',
          :segments_container => 'my_segments_container',
          :max_retries => 1,
          :retry_waitsec => 0
        )
      }
      before do
        cloud_io.stubs(:connection).returns(connection)
      end

      it 'creates containers once with retries' do
        connection.expects(:put_container).twice.
            with('my_container')
        connection.expects(:put_container).twice.
            with('my_segments_container').
            raises('error').then.returns(nil)

        cloud_io.send(:create_containers)
        cloud_io.send(:create_containers)
      end
    end

    context 'without SLO support' do
      let(:cloud_io) {
        CloudIO::CloudFiles.new(
          :container => 'my_container',
          :max_retries => 1,
          :retry_waitsec => 0
        )
      }
      before do
        cloud_io.stubs(:connection).returns(connection)
      end

      it 'creates containers once with retries' do
        connection.expects(:put_container).twice.
            with('my_container').
            raises('error').then.returns(nil)

        cloud_io.send(:create_containers)
        cloud_io.send(:create_containers)
      end
    end

  end # describe '#create_containers'

  describe '#put_object' do
    let(:cloud_io) {
      CloudIO::CloudFiles.new(
        :container => 'my_container',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }
    let(:file) { mock }

    before do
      cloud_io.stubs(:connection).returns(connection)
      md5_file = mock
      Digest::MD5.expects(:file).with('/src/file').returns(md5_file)
      md5_file.expects(:hexdigest).returns('abc123')
    end

    it 'calls put_object with ETag' do
      File.expects(:open).with('/src/file', 'r').yields(file)
      connection.expects(:put_object).
        with('my_container', 'dest/file', file, { 'ETag' => 'abc123' })
      cloud_io.send(:put_object, '/src/file', 'dest/file')
    end

    it 'fails after retries' do
      File.expects(:open).twice.with('/src/file', 'r').yields(file)
      connection.expects(:put_object).twice.
        with('my_container', 'dest/file', file, { 'ETag' => 'abc123' }).
        raises('error1').then.raises('error2')

      expect do
        cloud_io.send(:put_object, '/src/file', 'dest/file')
      end.to raise_error(CloudIO::Error) {|err|
        expect( err.message ).to eq(
          "CloudIO::Error: Max Retries (1) Exceeded!\n" +
          "  Operation: PUT 'my_container/dest/file'\n" +
          "  Be sure to check the log messages for each retry attempt.\n" +
          "--- Wrapped Exception ---\n" +
          "RuntimeError: error2"
        )
      }
      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "CloudIO::Error: Retry #1 of 1\n" +
        "  Operation: PUT 'my_container/dest/file'\n" +
        "--- Wrapped Exception ---\n" +
        "RuntimeError: error1"
      )
    end

    context 'with #days_to_keep set' do
      let(:cloud_io) {
        CloudIO::CloudFiles.new(
          :container => 'my_container',
          :days_to_keep => 1,
          :max_retries => 1,
          :retry_waitsec => 0
        )
      }
      let(:delete_at) { cloud_io.send(:delete_at) }

      it 'call put_object with X-Delete-At' do
        File.expects(:open).with('/src/file', 'r').yields(file)
        connection.expects(:put_object).with(
          'my_container', 'dest/file', file,
          { 'ETag' => 'abc123', 'X-Delete-At' => delete_at }
        )
        cloud_io.send(:put_object, '/src/file', 'dest/file')
      end
    end

  end # describe '#put_object'

  describe '#upload_segments' do
    let(:cloud_io) {
      CloudIO::CloudFiles.new(
        :segments_container => 'my_segments_container',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }
    let(:segment_bytes) { 1024**2 * 2 }
    let(:file_size) { segment_bytes + 250 }
    let(:digest_a) { 'de89461b64701958984c95d1bfb0065a' }
    let(:digest_b) { '382b6d2c391ad6871a9878241ef64cc9' }
    let(:file) { StringIO.new(('a' * segment_bytes) + ('b' * 250)) }

    before do
      cloud_io.stubs(:connection).returns(connection)
    end

    it 'uploads segments with ETags' do
      File.expects(:open).with('/src/file', 'r').yields(file)

      cloud_io.expects(:with_retries).
          with("PUT 'my_segments_container/dest/file/0001'").yields
      connection.expects(:put_object).with(
        'my_segments_container', 'dest/file/0001', nil,
        { 'ETag' => digest_a }
      ).multiple_yields(nil,nil,nil) # twice to read 2 MiB, third should not read

      cloud_io.expects(:with_retries).
          with("PUT 'my_segments_container/dest/file/0002'").yields
      connection.expects(:put_object).with(
        'my_segments_container', 'dest/file/0002', nil,
        { 'ETag' => digest_b }
      ).multiple_yields(nil,nil) # once to read 250 B, second should not read

      expected = [
        { :path => 'my_segments_container/dest/file/0001',
          :etag => digest_a,
          :size_bytes => segment_bytes },
        { :path => 'my_segments_container/dest/file/0002',
          :etag => digest_b,
          :size_bytes => 250 }
      ]
      expect(
        cloud_io.send(:upload_segments,
                      '/src/file', 'dest/file', segment_bytes, file_size)
      ).to eq expected
      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "  Uploading 2 SLO Segments...\n" +
        "  ...90% Complete..."
      )
    end

    it 'logs progress' do
      segment_bytes = 1024**2 * 1
      file_size = segment_bytes * 100
      file = StringIO.new('x' * file_size)
      File.expects(:open).with('/src/file', 'r').yields(file)
      cloud_io.stubs(:segment_md5)
      connection.stubs(:put_object).yields

      cloud_io.send(:upload_segments,
                    '/src/file', 'dest/file', segment_bytes, file_size)
      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "  Uploading 100 SLO Segments...\n" +
        "  ...10% Complete...\n" +
        "  ...20% Complete...\n" +
        "  ...30% Complete...\n" +
        "  ...40% Complete...\n" +
        "  ...50% Complete...\n" +
        "  ...60% Complete...\n" +
        "  ...70% Complete...\n" +
        "  ...80% Complete...\n" +
        "  ...90% Complete..."
      )
    end

    context 'when #days_to_keep is set' do
      let(:cloud_io) {
        CloudIO::CloudFiles.new(
          :segments_container => 'my_segments_container',
          :days_to_keep => 1,
          :max_retries => 1,
          :retry_waitsec => 0
        )
      }
      let(:delete_at) { cloud_io.send(:delete_at) }

      it 'uploads segments with X-Delete-At' do
        File.expects(:open).with('/src/file', 'r').yields(file)

        connection.expects(:put_object).with(
          'my_segments_container', 'dest/file/0001', nil,
          { 'ETag' => digest_a, 'X-Delete-At' => delete_at }
        ).multiple_yields(nil,nil) # twice to read 2 MiB

        connection.expects(:put_object).with(
          'my_segments_container', 'dest/file/0002', nil,
          { 'ETag' => digest_b, 'X-Delete-At' => delete_at }
        ).yields # once to read 250 B

        expected = [
          { :path => 'my_segments_container/dest/file/0001',
            :etag => digest_a,
            :size_bytes => segment_bytes },
          { :path => 'my_segments_container/dest/file/0002',
            :etag => digest_b,
            :size_bytes => 250 }
        ]
        expect(
          cloud_io.send(:upload_segments,
                        '/src/file', 'dest/file', segment_bytes, file_size)
        ).to eq expected
      end
    end

  end # describe '#upload_segments'

  describe '#upload_manifest' do
    let(:cloud_io) {
      CloudIO::CloudFiles.new(
        :container => 'my_container',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }
    let(:segments) { mock }

    before do
      cloud_io.stubs(:connection).returns(connection)
    end

    it 'uploads manifest with retries' do
      connection.expects(:put_static_obj_manifest).twice.
        with('my_container', 'dest/file', segments, {}).
        raises('error').then.returns(nil)

      cloud_io.send(:upload_manifest, 'dest/file', segments)
    end

    it 'fails when retries exceeded' do
      connection.expects(:put_static_obj_manifest).twice.
        with('my_container', 'dest/file', segments, {}).
        raises('error1').then.raises('error2')

      expect do
        cloud_io.send(:upload_manifest, 'dest/file', segments)
      end.to raise_error(CloudIO::Error) {|err|
        expect( err.message ).to eq(
          "CloudIO::Error: Max Retries (1) Exceeded!\n" +
          "  Operation: PUT SLO Manifest 'my_container/dest/file'\n" +
          "  Be sure to check the log messages for each retry attempt.\n" +
          "--- Wrapped Exception ---\n" +
          "RuntimeError: error2"
        )
      }
      expect( Logger.messages.map(&:lines).join("\n") ).to eq(
        "  Storing SLO Manifest 'my_container/dest/file'\n" +
        "CloudIO::Error: Retry #1 of 1\n" +
        "  Operation: PUT SLO Manifest 'my_container/dest/file'\n" +
        "--- Wrapped Exception ---\n" +
        "RuntimeError: error1"
      )
    end

    context 'with #days_to_keep set' do
      let(:cloud_io) {
        CloudIO::CloudFiles.new(
          :container => 'my_container',
          :days_to_keep => 1,
          :max_retries => 1,
          :retry_waitsec => 0
        )
      }
      let(:delete_at) { cloud_io.send(:delete_at) }

      it 'uploads manifest with X-Delete-At' do
        connection.expects(:put_static_obj_manifest).
          with('my_container', 'dest/file', segments, { 'X-Delete-At' => delete_at })

        cloud_io.send(:upload_manifest, 'dest/file', segments)
      end
    end

  end # describe '#upload_manifest'

  describe '#headers' do
    let(:cloud_io) {
      CloudIO::CloudFiles.new(
        :container => 'my_container',
        :max_retries => 1,
        :retry_waitsec => 0
      )
    }

    it 'returns empty headers' do
      expect( cloud_io.send(:headers) ).to eq({})
    end

    context 'with #days_to_keep set' do
      let(:cloud_io) { CloudIO::CloudFiles.new(:days_to_keep => 30) }

      it 'returns X-Delete-At header' do
        Timecop.freeze do
          expected = (Time.now.utc + 30 * 60**2 * 24).to_i
          headers = cloud_io.send(:headers)
          expect( headers['X-Delete-At'] ).to eq expected
        end
      end

      it 'returns the same headers for subsequent calls' do
        headers = cloud_io.send(:headers)
        expect( cloud_io.send(:headers) ).to eq headers
      end
    end
  end # describe '#headers'

  describe 'Object' do
    let(:cloud_io) { CloudIO::CloudFiles.new }
    let(:obj_data) { { 'name' => 'obj_name', 'hash' => 'obj_hash' } }
    let(:object) { CloudIO::CloudFiles::Object.new(cloud_io, obj_data) }

    describe '#initialize' do
      it 'creates Object from data' do
        expect( object.name ).to eq 'obj_name'
        expect( object.hash ).to eq 'obj_hash'
      end
    end

    describe '#slo?' do
      it 'returns true when object is an SLO' do
        cloud_io.expects(:head_object).once.
            with(object).
            returns(stub(:headers => { 'X-Static-Large-Object' => 'True' }))

        expect( object.slo? ).to be(true)
        expect( object.slo? ).to be(true)
      end

      it 'returns false when object is not an SLO' do
        cloud_io.expects(:head_object).with(object).returns(stub(:headers => {}))
        expect( object.slo? ).to be(false)
      end
    end

    describe '#marked_for_deletion?' do
      it 'returns true when object has X-Delete-At set' do
        cloud_io.expects(:head_object).once.
            with(object).
            returns(stub(:headers => { 'X-Delete-At' => '12345' }))

        expect( object.marked_for_deletion? ).to be(true)
        expect( object.marked_for_deletion? ).to be(true)
      end

      it 'returns false when object does not have X-Delete-At set' do
        cloud_io.expects(:head_object).with(object).returns(stub(:headers => {}))
        expect( object.marked_for_deletion? ).to be(false)
      end
    end
  end

end
end
