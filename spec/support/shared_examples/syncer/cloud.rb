# encoding: utf-8

shared_examples 'a subclass of Syncer::Cloud::Base' do
  let(:syncer_name) { described_class.name.sub('Backup::', '') }
  let(:s) { sequence '' }

  describe '#initialize' do

    it 'strips leading path separator' do
      pre_config = required_config
      klass = described_class.new do |syncer|
        pre_config.call(syncer)
        syncer.path = '/this/path'
      end
      expect( klass.path ).to eq 'this/path'
    end

  end # describe '#initialize'

  describe '#perform' do
    let(:syncer) { described_class.new(&required_config) }
    let(:cloud_io) { mock }
    let(:find_md5_data) {
      [['/local/path/sync_dir/unchanged_01',          'unchanged_01_md5'],
       ['/local/path/sync_dir/sub_dir/unchanged_02',  'unchanged_02_md5'],
       ['/local/path/sync_dir/changed_01',            'changed_01_md5'],
       ['/local/path/sync_dir/sub_dir/changed_02',    'changed_02_md5'],
       ['/local/path/sync_dir/missing_01',            'missing_01_md5']
      ].map do |path, md5|
        file = Backup::Syncer::Cloud::LocalFile.new(path)
        file.md5 = md5
        file
      end
    }
    let(:remote_files_data) {
      { 'unchanged_01'          => 'unchanged_01_md5',
        'sub_dir/unchanged_02'  => 'unchanged_02_md5',
        'changed_01'            => 'changed_01_md5_old',
        'sub_dir/changed_02'    => 'changed_02_md5_old',
        'orphan_01'             => 'orphan_01_md5',
        'sub_dir/orphan_02'     => 'orphan_02_md5' }
    }

    before do
      syncer.path = 'my_backups'
      syncer.directories { add '/local/path/sync_dir' }
      syncer.stubs(:cloud_io).returns(cloud_io)
      cloud_io.stubs(:upload)
      cloud_io.stubs(:delete)
      File.stubs(:exist?).returns(true)
    end

    context 'when no local or remote files are found' do
      before do
        syncer.stubs(:get_remote_files).
            with('my_backups/sync_dir').returns({})
        Backup::Syncer::Cloud::LocalFile.expects(:find_md5).
            with('/local/path/sync_dir', []).returns([])
      end

      it 'does not attempt to sync' do
        expected_messages = <<-EOS.gsub(/^ +/, '').chomp
          #{ syncer_name } Started...
          Gathering remote data for 'my_backups/sync_dir'...
          Gathering local data for '/local/path/sync_dir'...
          No local or remote files found

          Summary:
            Transferred Files: 0
            Orphaned Files: 0
            Unchanged Files: 0
          #{ syncer_name } Finished!
        EOS

        syncer.perform!

        expect( Backup::Logger.has_warnings? ).to be(false)
        expect(
          Backup::Logger.messages.map(&:lines).flatten.map(&:strip).join("\n")
        ).to eq expected_messages
      end
    end

    context 'without threads' do
      before do
        syncer.stubs(:get_remote_files).
            with('my_backups/sync_dir').returns(remote_files_data)
        Backup::Syncer::Cloud::LocalFile.expects(:find_md5).
            with('/local/path/sync_dir', []).returns(find_md5_data)
      end

      context 'without mirror' do

        it 'leaves orphaned files' do
          expected_messages = <<-EOS.gsub(/^ +/, '').chomp
            #{ syncer_name } Started...
            Gathering remote data for 'my_backups/sync_dir'...
            Gathering local data for '/local/path/sync_dir'...
            Syncing...
              [transferring] 'my_backups/sync_dir/changed_01'
              [transferring] 'my_backups/sync_dir/missing_01'
              [transferring] 'my_backups/sync_dir/sub_dir/changed_02'
              [orphaned] 'my_backups/sync_dir/orphan_01'
              [orphaned] 'my_backups/sync_dir/sub_dir/orphan_02'

            Summary:
              Transferred Files: 3
              Orphaned Files: 2
              Unchanged Files: 2
            #{ syncer_name } Finished!
          EOS

          syncer.perform!

          expect( Backup::Logger.has_warnings? ).to be(false)
          expect(
            Backup::Logger.messages.map(&:lines).flatten.map(&:strip).join("\n")
          ).to eq expected_messages
        end

      end # context 'without mirror'

      context 'with mirror' do
        before { syncer.mirror = true }

        it 'deletes orphaned files' do
          expected_messages = <<-EOS.gsub(/^ +/, '').chomp
            #{ syncer_name } Started...
            Gathering remote data for 'my_backups/sync_dir'...
            Gathering local data for '/local/path/sync_dir'...
            Syncing...
              [transferring] 'my_backups/sync_dir/changed_01'
              [transferring] 'my_backups/sync_dir/missing_01'
              [transferring] 'my_backups/sync_dir/sub_dir/changed_02'
              [removing] 'my_backups/sync_dir/orphan_01'
              [removing] 'my_backups/sync_dir/sub_dir/orphan_02'

            Summary:
              Transferred Files: 3
              Deleted Files: 2
              Unchanged Files: 2
            #{ syncer_name } Finished!
          EOS

          syncer.perform!

          expect( Backup::Logger.has_warnings? ).to be(false)
          expect(
            Backup::Logger.messages.map(&:lines).flatten.map(&:strip).join("\n")
          ).to eq expected_messages
        end

        it 'warns if delete fails' do
          cloud_io.stubs(:delete).raises('Delete Error')

          expected_messages = <<-EOS.gsub(/^ +/, '').chomp
            #{ syncer_name } Started...
            Gathering remote data for 'my_backups/sync_dir'...
            Gathering local data for '/local/path/sync_dir'...
            Syncing...
              [transferring] 'my_backups/sync_dir/changed_01'
              [transferring] 'my_backups/sync_dir/missing_01'
              [transferring] 'my_backups/sync_dir/sub_dir/changed_02'
              [removing] 'my_backups/sync_dir/orphan_01'
              [removing] 'my_backups/sync_dir/sub_dir/orphan_02'
            Syncer::Cloud::Error: Delete Operation Failed
            --- Wrapped Exception ---
            RuntimeError: Delete Error

            Summary:
              Transferred Files: 3
              Attempted to Delete: 2 (See log messages for actual results)
              Unchanged Files: 2
            #{ syncer_name } Finished!
          EOS

          syncer.perform!

          expect( Backup::Logger.has_warnings? ).to be(true)
          expect(
            Backup::Logger.messages.map(&:lines).flatten.map(&:strip).join("\n")
          ).to eq expected_messages
        end

      end # context 'with mirror'

      it 'skips files that are too large' do
        cloud_io.stubs(:upload).with(
          '/local/path/sync_dir/changed_01', 'my_backups/sync_dir/changed_01'
        ).raises(Backup::CloudIO::FileSizeError)

        expected_messages = <<-EOS.gsub(/^ +/, '').chomp
          #{ syncer_name } Started...
          Gathering remote data for 'my_backups/sync_dir'...
          Gathering local data for '/local/path/sync_dir'...
          Syncing...
            [transferring] 'my_backups/sync_dir/changed_01'
          Syncer::Cloud::Error: Skipping 'my_backups/sync_dir/changed_01'
          --- Wrapped Exception ---
          CloudIO::FileSizeError
            [transferring] 'my_backups/sync_dir/missing_01'
            [transferring] 'my_backups/sync_dir/sub_dir/changed_02'
            [orphaned] 'my_backups/sync_dir/orphan_01'
            [orphaned] 'my_backups/sync_dir/sub_dir/orphan_02'

          Summary:
            Transferred Files: 2
            Orphaned Files: 2
            Unchanged Files: 2
            Skipped Files: 1
          #{ syncer_name } Finished!
        EOS

        syncer.perform!

        expect( Backup::Logger.has_warnings? ).to be(true)
        expect(
          Backup::Logger.messages.map(&:lines).flatten.map(&:strip).join("\n")
        ).to eq expected_messages
      end

      it 'logs and raises error on upload failure' do
        cloud_io.stubs(:upload).raises('upload failure')
        Backup::Logger.expects(:error).with do |err|
          expect( err.message ).to eq 'upload failure'
        end
        expect do
          syncer.perform!
        end.to raise_error(Backup::Syncer::Cloud::Error)
      end

    end # context 'without threads'

    context 'with threads' do
      before do
        syncer.stubs(:get_remote_files).
            with('my_backups/sync_dir').returns(remote_files_data)
        Backup::Syncer::Cloud::LocalFile.expects(:find_md5).
            with('/local/path/sync_dir', []).returns(find_md5_data)

        syncer.thread_count = 20
        syncer.stubs(:sleep) # quicker tests
      end

      context 'without mirror' do

        it 'leaves orphaned files' do
          expected_head = <<-EOS.gsub(/^ +/, '')
            #{ syncer_name } Started...
            Gathering remote data for 'my_backups/sync_dir'...
            Gathering local data for '/local/path/sync_dir'...
            Syncing...
            Using 7 Threads
          EOS
          expected_tail = <<-EOS.gsub(/^ +/, '').chomp
              [orphaned] 'my_backups/sync_dir/orphan_01'
              [orphaned] 'my_backups/sync_dir/sub_dir/orphan_02'

            Summary:
              Transferred Files: 3
              Orphaned Files: 2
              Unchanged Files: 2
            #{ syncer_name } Finished!
          EOS

          syncer.mirror = false
          syncer.perform!

          expect( Backup::Logger.has_warnings? ).to be(false)
          messages = Backup::Logger.messages.
              map(&:lines).flatten.map(&:strip).join("\n")
          expect( messages ).to start_with expected_head
          expect( messages ).to end_with expected_tail
        end

      end # context 'without mirror'

      context 'with mirror' do
        before { syncer.mirror = true }

        it 'deletes orphaned files' do
          expected_head = <<-EOS.gsub(/^ +/, '')
            #{ syncer_name } Started...
            Gathering remote data for 'my_backups/sync_dir'...
            Gathering local data for '/local/path/sync_dir'...
            Syncing...
            Using 7 Threads
          EOS
          expected_tail = <<-EOS.gsub(/^ +/, '').chomp
              [removing] 'my_backups/sync_dir/orphan_01'
              [removing] 'my_backups/sync_dir/sub_dir/orphan_02'

            Summary:
              Transferred Files: 3
              Deleted Files: 2
              Unchanged Files: 2
            #{ syncer_name } Finished!
          EOS

          syncer.perform!

          expect( Backup::Logger.has_warnings? ).to be(false)
          messages = Backup::Logger.messages.
              map(&:lines).flatten.map(&:strip).join("\n")
          expect( messages ).to start_with expected_head
          expect( messages ).to end_with expected_tail
        end

        it 'warns if delete fails' do
          cloud_io.stubs(:delete).raises('Delete Error')

          expected_tail = <<-EOS.gsub(/^ +/, '').chomp
            Summary:
              Transferred Files: 3
              Attempted to Delete: 2 (See log messages for actual results)
              Unchanged Files: 2
            #{ syncer_name } Finished!
          EOS

          syncer.perform!

          expect( Backup::Logger.has_warnings? ).to be(true)
          messages = Backup::Logger.messages.
              map(&:lines).flatten.map(&:strip).join("\n")
          expect( messages ).to end_with expected_tail
          expect( messages ).to include(<<-EOS.gsub(/^ +/, ''))
            Syncer::Cloud::Error: Delete Operation Failed
            --- Wrapped Exception ---
            RuntimeError: Delete Error
          EOS
        end

      end # context 'with mirror'

      it 'skips files that are too large' do
        cloud_io.stubs(:upload).with(
          '/local/path/sync_dir/changed_01', 'my_backups/sync_dir/changed_01'
        ).raises(Backup::CloudIO::FileSizeError)

        expected_tail = <<-EOS.gsub(/^ +/, '').chomp
          Summary:
            Transferred Files: 2
            Orphaned Files: 2
            Unchanged Files: 2
            Skipped Files: 1
          #{ syncer_name } Finished!
        EOS

        syncer.perform!

        expect( Backup::Logger.has_warnings? ).to be(true)
        messages = Backup::Logger.messages.
            map(&:lines).flatten.map(&:strip).join("\n")
        expect( messages ).to end_with expected_tail
        expect( messages ).to include(<<-EOS.gsub(/^ +/, ''))
          Syncer::Cloud::Error: Skipping 'my_backups/sync_dir/changed_01'
          --- Wrapped Exception ---
          CloudIO::FileSizeError
        EOS
      end

      it 'logs and raises error on upload failure' do
        cloud_io.stubs(:upload).raises('upload failure')
        Backup::Logger.expects(:error).at_least_once.with do |err|
          expect( err.message ).to eq 'upload failure'
        end
        expect do
          syncer.perform!
        end.to raise_error(Backup::Syncer::Cloud::Error)
      end

    end # context 'with threads'

  end # describe '#perform'

end # shared_examples 'a subclass of Syncer::Cloud::Base'

shared_examples 'Deprecation: #concurrency_type and #concurrency_level' do
  after { described_class.clear_defaults! }

  context 'when desired #concurrency_type is :threads' do
    context 'when only #concurrency_type is set' do
      before do
        Backup::Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Backup::Configuration::Error
          expect( err.message ).to match(/Use #thread_count instead/)
        }
      end

      specify 'set as a default' do
        described_class.defaults do |klass|
          klass.concurrency_type = :threads
        end
        syncer = described_class.new(&required_config)
        expect( syncer.thread_count ).to be 2
      end

      specify 'set directly' do
        pre_config = required_config
        syncer = described_class.new do |klass|
          pre_config.call(klass)
          klass.concurrency_type = :threads
        end
        expect( syncer.thread_count ).to be 2
      end
    end

    context 'when both #concurrency_type and #concurrency_level are set' do
      before do
        Backup::Logger.expects(:warn).twice.with {|err|
          expect( err ).to be_an_instance_of Backup::Configuration::Error
          expect( err.message ).to match(/Use #thread_count instead/)
        }
      end

      context 'when #concurrency_type is set before #concurrency_level' do
        specify 'set as a default' do
          described_class.defaults do |klass|
            klass.concurrency_type = :threads
            klass.concurrency_level = 5
          end
          syncer = described_class.new(&required_config)
          expect( syncer.thread_count ).to be 5
        end

        specify 'set directly' do
          pre_config = required_config
          syncer = described_class.new do |klass|
            pre_config.call(klass)
            klass.concurrency_type = :threads
            klass.concurrency_level = 5
          end
          expect( syncer.thread_count ).to be 5
        end
      end

      context 'when #concurrency_level is set before #concurrency_type' do
        specify 'set as a default' do
          described_class.defaults do |klass|
            klass.concurrency_level = 5
            klass.concurrency_type = :threads
          end
          syncer = described_class.new(&required_config)
          expect( syncer.thread_count ).to be 5
        end

        specify 'set directly' do
          pre_config = required_config
          syncer = described_class.new do |klass|
            pre_config.call(klass)
            klass.concurrency_level = 5
            klass.concurrency_type = :threads
          end
          expect( syncer.thread_count ).to be 5
        end
      end
    end
  end

  context 'when desired #concurrency_type is :processes' do
    context 'when only #concurrency_type is set' do
      before do
        Backup::Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Backup::Configuration::Error
          expect( err.message ).to match(/Use #thread_count instead/)
        }
      end

      specify 'set as a default' do
        described_class.defaults do |klass|
          klass.concurrency_type = :processes
        end
        syncer = described_class.new(&required_config)
        expect( syncer.thread_count ).to be 0
      end

      specify 'set directly' do
        pre_config = required_config
        syncer = described_class.new do |klass|
          pre_config.call(klass)
          klass.concurrency_type = :processes
        end
        expect( syncer.thread_count ).to be 0
      end
    end

    context 'when both #concurrency_type and #concurrency_level are set' do
      before do
        Backup::Logger.expects(:warn).twice.with {|err|
          expect( err ).to be_an_instance_of Backup::Configuration::Error
          expect( err.message ).to match(/Use #thread_count instead/)
        }
      end

      context 'when #concurrency_type is set before #concurrency_level' do
        specify 'set as a default' do
          described_class.defaults do |klass|
            klass.concurrency_type = :processes
            klass.concurrency_level = 5
          end
          syncer = described_class.new(&required_config)
          expect( syncer.thread_count ).to be 0
        end

        specify 'set directly' do
          pre_config = required_config
          syncer = described_class.new do |klass|
            pre_config.call(klass)
            klass.concurrency_type = :processes
            klass.concurrency_level = 5
          end
          expect( syncer.thread_count ).to be 0
        end
      end

      context 'when #concurrency_level is set before #concurrency_type' do
        specify 'set as a default' do
          described_class.defaults do |klass|
            klass.concurrency_level = 5
            klass.concurrency_type = :processes
          end
          syncer = described_class.new(&required_config)
          expect( syncer.thread_count ).to be 0
        end

        specify 'set directly' do
          pre_config = required_config
          syncer = described_class.new do |klass|
            pre_config.call(klass)
            klass.concurrency_level = 5
            klass.concurrency_type = :processes
          end
          expect( syncer.thread_count ).to be 0
        end
      end
    end
  end
end # shared_examples 'deprecation: #concurrency_type and #concurrency_level'
