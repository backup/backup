# encoding: utf-8
require File.expand_path('../../../spec_helper.rb', __FILE__)

module Backup
describe Syncer::Cloud::LocalFile do

  describe '.find' do

    before do
      @tmpdir = Dir.mktmpdir('backup_spec')
      SandboxFileUtils.activate!(@tmpdir)
      FileUtils.mkdir_p File.join(@tmpdir, 'sync_dir/sub_dir')
      Utilities.unstub(:utility)
    end

    after do
      FileUtils.rm_r(@tmpdir, :force => true, :secure => true)
    end

    it 'returns an empty hash if no files are found' do
      expect( described_class.find(@tmpdir) ).to eq({})
    end

    context 'with test files' do
      let(:test_files) {
        { 'sync_dir/one.file'           => 'c9f90c31589526ef50cc974a614038d5',
          'sync_dir/two.file'           => '1d26903171cef8b1d7eb035ca049f492',
          'sync_dir/sub_dir/three.file' => '4ccdba38597e718ed00e3344dc78b6a1',
          'base_dir.file'               => 'a6cfa67bfa0e16402b76d4560c0baa3d' }
      }
      before do
        test_files.keys.each do |path|
          File.open(File.join(@tmpdir, path), 'w') {|file| file.write path }
        end
      end

      it 'returns a Hash of LocalFile objects, keyed by relative path' do
        Dir.chdir(@tmpdir) do
          bad_file = "sync_dir/bad\xFFfile"
          sanitized_bad_file = "sync_dir/bad\xEF\xBF\xBDfile"
          FileUtils.touch bad_file

          Logger.expects(:warn).with(
            "\s\s[skipping] #{ File.expand_path(sanitized_bad_file) }\n" +
            "\s\sPath Contains Invalid UTF-8 byte sequences"
          )

          local_files = described_class.find('sync_dir')
          expect( local_files.keys.count ).to be 3
          local_files.each do |relative_path, local_file|
            expect( local_file.path ).to eq(
              File.expand_path("sync_dir/#{ relative_path }")
            )
            expect( local_file.md5 ).to eq(
              test_files["sync_dir/#{ relative_path }"]
            )
          end
        end
      end

      it 'ignores excluded files' do
        expect(
          described_class.find(@tmpdir, ['**/two.*', /sub|base_dir/]).keys
        ).to eq(['sync_dir/one.file'])
      end

      it 'follows symlinks' do
        FileUtils.ln_s File.join(@tmpdir, 'base_dir.file'),
                       File.join(@tmpdir, 'sync_dir/link')

        found = described_class.find(@tmpdir)
        expect( found.keys ).to include('sync_dir/link')
        expect( found['sync_dir/link'].md5 ).to eq(test_files['base_dir.file'])
      end
    end

  end

end
end
