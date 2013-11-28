# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

module Backup
describe Splitter do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:package) { model.package }
  let(:splitter) { Splitter.new(model, 250, 2) }
  let(:splitter_long_suffix) { Splitter.new(model, 250, 3) }
  let(:s) { sequence '' }

  before do
    Splitter.any_instance.stubs(:utility).with(:split).returns('split')
  end

  # Note: BSD split will not accept a 'M' suffix for the byte size
  # e.g. split -a 2 -b 250M

  describe '#initialize' do
    it 'sets instance variables' do
      expect( splitter.package       ).to be package
      expect( splitter.chunk_size    ).to be 250
	    expect( splitter.suffix_length ).to be 2
	    expect( splitter_long_suffix.package       ).to be package
	    expect( splitter_long_suffix.chunk_size    ).to be 250
	    expect( splitter_long_suffix.suffix_length ).to be 3
    end
  end

  describe '#split_with' do
    let(:given_block) { mock }
    let(:block) { lambda {|arg| given_block.got(arg) } }

    context 'when the final package is large enough to be split' do
      before do
        splitter.stubs(:chunks).returns(
          ['/tmp/test_trigger.tar-aa', '/tmp/test_trigger.tar-ab']
        )
      end

      it 'updates chunk_suffixes for the package' do
        Logger.expects(:info).in_sequence(s).with(
          'Splitter configured with a chunk size of 250MB and suffix length of 2.'
        )

        given_block.expects(:got).in_sequence(s).with(
          "split -a 2 -b 250m - '#{ File.join(Config.tmp_path, 'test_trigger.tar-') }'"
        )

        FileUtils.expects(:mv).never

        splitter.split_with(&block)

        expect( package.chunk_suffixes ).to eq ['aa', 'ab']
      end
    end

    context 'when the final package is not large enough to be split' do
      before do
        splitter.stubs(:chunks).returns(['/tmp/test_trigger.tar-aa'])
      end

      it 'removes the suffix from the single file output by split' do
        Logger.expects(:info).in_sequence(s).with(
          'Splitter configured with a chunk size of 250MB and suffix length of 2.'
        )

        given_block.expects(:got).in_sequence(s).with(
          "split -a 2 -b 250m - '#{ File.join(Config.tmp_path, 'test_trigger.tar-') }'"
        )

        FileUtils.expects(:mv).in_sequence(s).with(
          File.join(Config.tmp_path, 'test_trigger.tar-aa'),
          File.join(Config.tmp_path, 'test_trigger.tar')
        )

        splitter.split_with(&block)

        expect( package.chunk_suffixes ).to eq []
      end
    end

    context 'when the final package is large enough to be split with non-default suffix length' do
      before do
        splitter_long_suffix.stubs(:chunks).returns(
          ['/tmp/test_trigger.tar-aaa', '/tmp/test_trigger.tar-aab']
        )
      end

      it 'updates chunk_suffixes for the package' do
        Logger.expects(:info).in_sequence(s).with(
          'Splitter configured with a chunk size of 250MB and suffix length of 3.'
        )

        given_block.expects(:got).in_sequence(s).with(
          "split -a 3 -b 250m - '#{ File.join(Config.tmp_path, 'test_trigger.tar-') }'"
        )

        FileUtils.expects(:mv).never

        splitter_long_suffix.split_with(&block)

        expect( package.chunk_suffixes ).to eq ['aaa', 'aab']
      end
    end

    context 'when the final package is not large enough to be split with non-default suffix length' do
      before do
        splitter_long_suffix.stubs(:chunks).returns(['/tmp/test_trigger.tar-aaa'])
      end

      it 'removes the suffix from the single file output by split' do
        Logger.expects(:info).in_sequence(s).with(
          'Splitter configured with a chunk size of 250MB and suffix length of 3.'
        )

        given_block.expects(:got).in_sequence(s).with(
          "split -a 3 -b 250m - '#{ File.join(Config.tmp_path, 'test_trigger.tar-') }'"
        )

        FileUtils.expects(:mv).in_sequence(s).with(
          File.join(Config.tmp_path, 'test_trigger.tar-aaa'),
          File.join(Config.tmp_path, 'test_trigger.tar')
        )

        splitter_long_suffix.split_with(&block)

        expect( package.chunk_suffixes ).to eq []
      end
    end

  end # describe '#split_with'

  describe '#chunks' do
    before do
      @tmpdir = Dir.mktmpdir('backup_spec')
      SandboxFileUtils.activate!(@tmpdir)
      Config.update(:root_path => @tmpdir)
      FileUtils.mkdir_p(Config.tmp_path)
    end

    after do
      FileUtils.rm_r(@tmpdir, :force => true, :secure => true)
    end

    it 'should return a sorted array of chunked file paths' do
      files = [
        'test_trigger.tar-aa',
        'test_trigger.tar-ab',
        'other_trigger.tar-aa'
      ].map {|name| File.join(Config.tmp_path, name) }
      FileUtils.touch(files)

      expect( splitter.send(:chunks) ).to eq files[0..1]
    end
  end

end
end
