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
    
    def create_test_files
      @test_files = {
        'sync_dir/one.file'           => 'c9f90c31589526ef50cc974a614038d5',
        'sync_dir/two.file'           => '1d26903171cef8b1d7eb035ca049f492',
        'sync_dir/sub_dir/three.file' => '4ccdba38597e718ed00e3344dc78b6a1'
      }
      @test_files.keys.each do |path|
        File.open(path, 'w') {|file| file.write path }
      end
    end

    after do
      FileUtils.rm_r(@tmpdir, :force => true, :secure => true)
    end

    it 'returns a Hash of LocalFile objects, keyed by relative path' do
      Dir.chdir(@tmpdir) do
        create_test_files
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
            @test_files["sync_dir/#{ relative_path }"]
          )
        end
      end
    end
    
    it 'ignores excluded files' do
      Dir.chdir(@tmpdir) do
        create_test_files
        expect( described_class.find(@tmpdir, ['**/two.*', /sub/]).keys ).to eq(['sync_dir/one.file'])
      end
    end

    it 'ignores symlinks' do
      Dir.chdir(@tmpdir) do
        create_test_files
        File.symlink 'sync_dir/one.file', 'sync_dir/link'
        
        expect( described_class.find(@tmpdir).keys ).not_to include('sync_dir/link')
      end
    end

    it 'returns an empty hash if no files are found' do
      expect( described_class.find(@tmpdir) ).to eq({})
    end

  end

end
end
