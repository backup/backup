# encoding: utf-8
require File.expand_path('../../../spec_helper.rb', __FILE__)

describe 'Backup::Syncer::Cloud::Base' do
  let(:syncer) { Backup::Syncer::Cloud::Base.new }
  let(:s)      { sequence '' }

  it 'should be a subclass of Syncer::Base' do
    Backup::Syncer::Cloud::Base.
      superclass.should == Backup::Syncer::Base
  end

  it 'should establish a class constant for a Mutex' do
    Backup::Syncer::Cloud::Base::MUTEX.should be_an_instance_of Mutex
  end

  describe '#initialize' do
    after { Backup::Syncer::Cloud::Base.clear_defaults! }

    it 'should load pre-configured defaults through Syncer::Base' do
      Backup::Syncer::Cloud::Base.any_instance.expects(:load_defaults!)
      syncer
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use default values if none are given' do
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.concurrency_type.should  == false
        syncer.concurrency_level.should == 2
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Syncer::Cloud::Base.defaults do |cloud|
          cloud.concurrency_type  = 'default_concurrency_type'
          cloud.concurrency_level = 'default_concurrency_level'
        end
      end

      it 'should use pre-configured defaults' do
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.concurrency_type.should  == 'default_concurrency_type'
        syncer.concurrency_level.should == 'default_concurrency_level'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#perform' do
    let(:sync_context) { mock }

    before do
      syncer.stubs(:repository_object).returns(:a_repository_object)

      Backup::Logger.expects(:message).with(
        "Syncer::Cloud::Base started the syncing process:\n" +
        "\s\sConcurrency: false Level: 2"
      )
      Backup::Logger.expects(:message).with(
        'Syncer::Cloud::Base Syncing Complete!'
      )
    end

    it 'should sync each directory' do
      syncer.directories do
        add '/dir/one'
        add '/dir/two'
      end

      Backup::Syncer::Cloud::Base::SyncContext.expects(:new).in_sequence(s).with(
        '/dir/one', :a_repository_object, 'backups'
      ).returns(sync_context)
      sync_context.expects(:sync!).in_sequence(s).with(
        false, false, 2
      )
      Backup::Syncer::Cloud::Base::SyncContext.expects(:new).in_sequence(s).with(
        '/dir/two', :a_repository_object, 'backups'
      ).returns(sync_context)
      sync_context.expects(:sync!).in_sequence(s).with(
        false, false, 2
      )

      syncer.perform!
    end

    it 'should ensure each directory path is expanded with no trailing slash' do
      syncer.directories do
        add '/dir/one/'
        add 'dir/two'
      end

      Backup::Syncer::Cloud::Base::SyncContext.expects(:new).with(
        '/dir/one', :a_repository_object, 'backups'
      ).returns(sync_context)

      Backup::Syncer::Cloud::Base::SyncContext.expects(:new).with(
        File.expand_path('dir/two'), :a_repository_object, 'backups'
      ).returns(sync_context)

      sync_context.stubs(:sync!)

      syncer.perform!
    end
  end # describe '#perform'

  describe 'Cloud::Base::SyncContext' do
    let(:bucket) { mock }
    let(:sync_context) do
      Backup::Syncer::Cloud::Base::SyncContext.new(
        '/dir/to/sync', bucket, 'backups'
      )
    end

    describe '#initialize' do
      it 'should set variables' do
        sync_context.directory.should   == '/dir/to/sync'
        sync_context.bucket.should      == bucket
        sync_context.path.should        == 'backups'
        sync_context.remote_base.should == 'backups/sync'
      end
    end

    describe '#sync!' do
      let(:all_files_array) { mock }

      before do
        sync_context.stubs(:all_file_names).returns(all_files_array)
      end

      context 'when concurrency_type is set to `false`' do
        it 'syncs files without concurrency' do
          all_files_array.expects(:each).in_sequence(s).
            multiple_yields('foo.file', 'foo_dir/foo.file')

          sync_context.expects(:sync_file).in_sequence(s).
              with('foo.file', :mirror)
          sync_context.expects(:sync_file).in_sequence(s).
              with('foo_dir/foo.file', :mirror)

          sync_context.sync!(:mirror, false, :foo)
        end
      end

      context 'when concurrency_type is set to `:threads`' do
        it 'uses `concurrency_level` number of threads for concurrency' do
          Parallel.expects(:each).in_sequence(s).with(
            all_files_array, :in_threads => :num_of_threads
          ).multiple_yields('foo.file', 'foo_dir/foo.file')

          sync_context.expects(:sync_file).in_sequence(s).
              with('foo.file', :mirror)
          sync_context.expects(:sync_file).in_sequence(s).
              with('foo_dir/foo.file', :mirror)

          sync_context.sync!(:mirror, :threads, :num_of_threads)
        end
      end

      context 'when concurrency_type is set to `:processes`' do
        it 'uses `concurrency_level` number of processes for concurrency' do
          Parallel.expects(:each).in_sequence(s).with(
            all_files_array, :in_processes => :num_of_processes
          ).multiple_yields('foo.file', 'foo_dir/foo.file')

          sync_context.expects(:sync_file).in_sequence(s).
              with('foo.file', :mirror)
          sync_context.expects(:sync_file).in_sequence(s).
              with('foo_dir/foo.file', :mirror)

          sync_context.sync!(:mirror, :processes, :num_of_processes)
        end
      end

      context 'when concurrency_type setting is invalid' do
        it 'should raise an error' do
          expect do
            sync_context.sync!(:foo, 'unknown type', :foo)
          end.to raise_error(
            Backup::Errors::Syncer::Cloud::ConfigurationError,
            'Syncer::Cloud::ConfigurationError: ' +
            "Unknown concurrency_type setting: \"unknown type\""
          )
        end
      end
    end # describe '#sync!'

    describe '#all_file_names' do
      let(:local_files_hash) do
        { 'file_b' => :foo, 'file_a' => :foo, 'dir_a/file_b' => :foo }
      end
      let(:remote_files_hash) do
        { 'file_c' => :foo, 'file_a' => :foo, 'dir_a/file_a' => :foo }
      end
      let(:local_remote_union_array) do
        ['dir_a/file_a', 'dir_a/file_b', 'file_a', 'file_b', 'file_c']
      end

      it 'returns and caches a sorted union of local and remote file names' do
        sync_context.expects(:local_files).once.returns(local_files_hash)
        sync_context.expects(:remote_files).once.returns(remote_files_hash)

        sync_context.send(:all_file_names).should == local_remote_union_array
        sync_context.instance_variable_get(:@all_file_names).
            should == local_remote_union_array
        sync_context.send(:all_file_names).should == local_remote_union_array
      end
    end # describe '#all_file_names'

    describe '#local_files' do
      let(:local_file_class)  { Backup::Syncer::Cloud::Base::LocalFile }
      let(:local_hashes_data) { "line1\nline2\nbad\xFFline\nline3" }

      let(:local_file_a)  { stub(:relative_path => 'file_a') }
      let(:local_file_b)  { stub(:relative_path => 'file_b') }
      let(:local_file_c)  { stub(:relative_path => 'file_c') }
      let(:local_files_hash) do
        { 'file_a' => local_file_a,
          'file_b' => local_file_b,
          'file_c' => local_file_c }
      end

      it 'should return and caches a hash of LocalFile objects' do
        sync_context.expects(:local_hashes).once.returns(local_hashes_data)

        local_file_class.expects(:new).once.with('/dir/to/sync', "line1\n").
            returns(local_file_a)
        local_file_class.expects(:new).once.with('/dir/to/sync', "line2\n").
            returns(local_file_b)
        local_file_class.expects(:new).once.with('/dir/to/sync', "bad\xFFline\n").
            returns(nil)
        local_file_class.expects(:new).once.with('/dir/to/sync', "line3").
            returns(local_file_c)

        sync_context.send(:local_files).should == local_files_hash
        sync_context.instance_variable_get(:@local_files).
            should == local_files_hash
        sync_context.send(:local_files).should == local_files_hash
      end

      # Note: don't use methods that validate encoding
      it 'will raise an Exception if String#split is used',
          :if => RUBY_VERSION >= '1.9' do
        expect do
          "line1\nbad\xFFline\nline3".split("\n")
        end.to raise_error(ArgumentError, 'invalid byte sequence in UTF-8')
      end
    end # describe '#local_files'

    describe '#local_hashes' do
      it 'should collect file paths and MD5 checksums for @directory' do
        Backup::Logger.expects(:message).with(
          "\s\sGenerating checksums for '/dir/to/sync'"
        )
        sync_context.expects(:`).with(
          "find '/dir/to/sync' -print0 | xargs -0 openssl md5 2> /dev/null"
        ).returns('MD5(tmp/foo)= 0123456789abcdefghijklmnopqrstuv')

        sync_context.send(:local_hashes).should ==
          'MD5(tmp/foo)= 0123456789abcdefghijklmnopqrstuv'
      end
    end

    describe '#remote_files' do
      let(:repository_object) { mock }
      let(:repository_files)  { mock }
      let(:file_objects)      { mock }
      let(:file_obj_a)        { stub(:key => 'file_a') }
      let(:file_obj_b)        { stub(:key => 'file_b') }
      let(:file_obj_c)        { stub(:key => 'dir/file_c') }
      let(:remote_files_hash) do
        { 'file_a'      => file_obj_a,
          'file_b'      => file_obj_b,
          'dir/file_c'  => file_obj_c }
      end

      before do
        sync_context.instance_variable_set(:@bucket, repository_object)

        repository_object.expects(:files).once.returns(repository_files)
        repository_files.expects(:all).once.with(:prefix => 'backups/sync').
            returns(file_objects)
        file_objects.expects(:each).once.multiple_yields(
          file_obj_a, file_obj_b, file_obj_c
        )

        # this is to avoid: unexpected invocation: #<Mock>.to_a()
        # only 1.9.2 seems affected by this
        if RUBY_VERSION == '1.9.2'
          file_obj_a.stubs(:to_a)
          file_obj_b.stubs(:to_a)
          file_obj_c.stubs(:to_a)
        end
      end

      context 'when it returns and caches a hash of repository file objects' do
        it 'should remove the @remote_base from the path for the hash key' do
          sync_context.send(:remote_files).should == remote_files_hash
          sync_context.instance_variable_get(:@remote_files).
              should == remote_files_hash
          sync_context.send(:remote_files).should == remote_files_hash
        end
      end
    end # describe '#remote_files'

    describe '#sync_file' do
      let(:local_file) do
        stub(
          :path => '/dir/to/sync/sync.file',
          :md5 => '0123456789abcdefghijklmnopqrstuv')
      end
      let(:remote_file) do
        stub(:path => 'backups/sync/sync.file')
      end
      let(:file) { mock }
      let(:repository_object) { mock }
      let(:repository_files)  { mock }

      before do
        sync_context.instance_variable_set(:@bucket, repository_object)
        repository_object.stubs(:files).returns(repository_files)
      end

      context 'when the requested file to sync exists locally' do
        before do
          sync_context.stubs(:local_files).returns(
            { 'sync.file' => local_file }
          )
          File.expects(:exist?).with('/dir/to/sync/sync.file').returns(true)
        end

        context 'when the MD5 checksum matches the remote file' do
          before do
            remote_file.stubs(:etag).returns('0123456789abcdefghijklmnopqrstuv')
            sync_context.stubs(:remote_files).returns(
              { 'sync.file' => remote_file }
            )
          end

          it 'should skip the file' do
            File.expects(:open).never
            Backup::Syncer::Cloud::Base::MUTEX.expects(:synchronize).yields
            Backup::Logger.expects(:message).with(
              "\s\s[skipping] 'backups/sync/sync.file'"
            )

            sync_context.send(:sync_file, 'sync.file', :foo)
          end
        end

        context 'when the MD5 checksum does not match the remote file' do
          before do
            remote_file.stubs(:etag).returns('vutsrqponmlkjihgfedcba9876543210')
            sync_context.stubs(:remote_files).returns(
              { 'sync.file' => remote_file }
            )
          end

          it 'should upload the file' do
            Backup::Syncer::Cloud::Base::MUTEX.expects(:synchronize).yields
            Backup::Logger.expects(:message).with(
              "\s\s[transferring] 'backups/sync/sync.file'"
            )

            File.expects(:open).with('/dir/to/sync/sync.file', 'r').yields(file)
            repository_files.expects(:create).with(
              :key  => 'backups/sync/sync.file',
              :body => file
            )

            sync_context.send(:sync_file, 'sync.file', :foo)
          end
        end

        context 'when the requested file does not exist on the remote' do
          before do
            sync_context.stubs(:remote_files).returns({})
          end

          it 'should upload the file' do
            Backup::Syncer::Cloud::Base::MUTEX.expects(:synchronize).yields
            Backup::Logger.expects(:message).with(
              "\s\s[transferring] 'backups/sync/sync.file'"
            )

            File.expects(:open).with('/dir/to/sync/sync.file', 'r').yields(file)
            repository_files.expects(:create).with(
              :key  => 'backups/sync/sync.file',
              :body => file
            )

            sync_context.send(:sync_file, 'sync.file', :foo)
          end
        end
      end

      context 'when the requested file does not exist locally' do
        before do
          sync_context.stubs(:remote_files).returns(
            { 'sync.file' => remote_file }
          )
          sync_context.stubs(:local_files).returns({})
        end

        context 'when the `mirror` option is set to true' do
          it 'should remove the file from the remote' do
            Backup::Syncer::Cloud::Base::MUTEX.expects(:synchronize).yields
            Backup::Logger.expects(:message).with(
              "\s\s[removing] 'backups/sync/sync.file'"
            )

            remote_file.expects(:destroy)

            sync_context.send(:sync_file, 'sync.file', true)
          end
        end

        context 'when the `mirror` option is set to false' do
          it 'should leave the file on the remote' do
            Backup::Syncer::Cloud::Base::MUTEX.expects(:synchronize).yields
            Backup::Logger.expects(:message).with(
              "\s\s[leaving] 'backups/sync/sync.file'"
            )

            remote_file.expects(:destroy).never

            sync_context.send(:sync_file, 'sync.file', false)
          end
        end
      end
    end # describe '#sync_file'
  end # describe 'Cloud::Base::SyncContext'

  describe 'Cloud::Base::LocalFile' do
    let(:local_file_class) { Backup::Syncer::Cloud::Base::LocalFile }

    describe '#new' do
      describe 'wrapping #initialize and using #sanitize to validate objects' do
        context 'when the path is valid UTF-8' do
          let(:local_file) do
            local_file_class.new(
              'foo',
              'MD5(foo)= 0123456789abcdefghijklmnopqrstuv'
            )
          end

          it 'should return the new object' do
            Backup::Logger.expects(:warn).never

            local_file.should be_an_instance_of local_file_class
          end
        end

        context 'when the path contains invalid UTF-8' do
          let(:local_file) do
            local_file_class.new(
              "/bad/pa\xFFth",
              "MD5(/bad/pa\xFFth/to/file)= 0123456789abcdefghijklmnopqrstuv"
            )
          end
          it 'should return nil and log a warning' do
            Backup::Logger.expects(:warn).with(
              "\s\s[skipping] /bad/pa\xEF\xBF\xBDth/to/file\n" +
              "\s\sPath Contains Invalid UTF-8 byte sequences"
            )

            local_file.should be_nil
          end
        end
      end
    end # describe '#new'

    describe '#initialize' do
      let(:local_file) do
        local_file_class.new(:directory, :line)
      end

      before do
        local_file_class.any_instance.expects(:sanitize).with(:directory).
          returns('/dir/to/sync')
        local_file_class.any_instance.expects(:sanitize).with(:line).
          returns("MD5(/dir/to/sync/subdir/sync.file)= 0123456789abcdefghijklmnopqrstuv\n")
      end

      it 'should determine @path, @relative_path and @md5' do
        local_file.path.should == '/dir/to/sync/subdir/sync.file'
        local_file.relative_path.should == 'subdir/sync.file'
        local_file.md5.should == '0123456789abcdefghijklmnopqrstuv'
      end

      it 'should return nil if the object is invalid' do
        local_file_class.any_instance.expects(:invalid?).returns(true)
        Backup::Logger.expects(:warn)
        local_file.should be_nil
      end
    end # describe '#initialize'

    describe '#sanitize' do
      let(:local_file) do
        local_file_class.new('foo', 'MD5(foo)= 0123456789abcdefghijklmnopqrstuv')
      end

      it 'should replace any invalid UTF-8 characters' do
        local_file.send(:sanitize, "/path/to/d\xFFir/subdir/sync\xFFfile").
          should == "/path/to/d\xEF\xBF\xBDir/subdir/sync\xEF\xBF\xBDfile"
      end

      it 'should flag the LocalFile object as invalid' do
        local_file.send(:sanitize, "/path/to/d\xFFir/subdir/sync\xFFfile")
        local_file.invalid?.should be_true
      end
    end # describe '#sanitize'
  end # describe 'Cloud::Base::LocalFile'
end
