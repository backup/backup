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

    it 'returns a Hash of LocalFile objects, keyed by relative path' do
      test_files = {
        'sync_dir/one.file'           => 'c9f90c31589526ef50cc974a614038d5',
        'sync_dir/two.file'           => '1d26903171cef8b1d7eb035ca049f492',
        'sync_dir/sub_dir/three.file' => '4ccdba38597e718ed00e3344dc78b6a1',
        'sync_dir/sub_dir/four.excl'  => '5adae9086b7842e3bdc8e58d6d4799c1',
      }

      Dir.chdir(@tmpdir) do
        test_files.keys.each do |path|
          File.open(path, 'w') {|file| file.write path }
        end
        bad_file = "sync_dir/bad\xFFfile"
        sanitized_bad_file = "sync_dir/bad\xEF\xBF\xBDfile"
        FileUtils.touch bad_file

        Logger.expects(:warn).with(
          "\s\s[skipping] #{ File.expand_path(sanitized_bad_file) }\n" +
          "\s\sPath Contains Invalid UTF-8 byte sequences"
        )

        local_files = described_class.find('sync_dir', '*.excl')
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

    it 'returns an empty hash if no files are found' do
      expect( described_class.find(@tmpdir) ).to eq({})
    end

  end

end
end
