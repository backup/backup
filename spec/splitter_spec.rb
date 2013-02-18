# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe Backup::Splitter do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:splitter) { Backup::Splitter.new(model, 250) }
  let(:package) { mock }

  it 'should include Utilities::Helpers' do
    Backup::Splitter.
        include?(Backup::Utilities::Helpers).should be_true
  end

  describe '#initialize' do
    it 'should set instance variables' do
      splitter.instance_variable_get(:@model).should be(model)
      splitter.instance_variable_get(:@chunk_size).should be(250)
    end
  end

  describe '#split_with' do
    it 'should yield the split command, performing before/after methods' do
      s = sequence ''
      given_block = mock
      block = lambda {|arg| given_block.got(arg) }
      splitter.instance_variable_set(:@split_command, 'split command')

      splitter.expects(:before_packaging).in_sequence(s)
      given_block.expects(:got).in_sequence(s).with('split command')
      splitter.expects(:after_packaging).in_sequence(s)

      splitter.split_with(&block)
    end
  end

  # Note: using a 'M' suffix for the byte size is not OSX compatible
  describe '#before_packaging' do
    before do
      model.instance_variable_set(:@package, package)
      splitter.expects(:utility).with(:split).returns('split')
      package.expects(:basename).returns('base_filename')
    end

    it 'should set @package and @split_command' do
      Backup::Logger.expects(:info).with(
        'Splitter configured with a chunk size of 250MB.'
      )
      splitter.send(:before_packaging)

      splitter.instance_variable_get(:@package).should be(package)

      split_suffix = File.join(Backup::Config.tmp_path, 'base_filename-')
      splitter.instance_variable_get(:@split_command).should ==
          "split -b 250m - '#{ split_suffix }'"
    end
  end

  describe '#after_packaging' do
    before do
      splitter.instance_variable_set(:@package, package)
    end

    context 'when splitting occurred during packaging' do
      before do
        splitter.expects(:chunk_suffixes).returns(['aa', 'ab'])
      end

      it 'should set the chunk_suffixes for the package' do
        package.expects(:chunk_suffixes=).with(['aa', 'ab'])
        splitter.send(:after_packaging)
      end
    end

    context 'when splitting did not occur during packaging' do
      before do
        splitter.expects(:chunk_suffixes).returns(['aa'])
        package.expects(:basename).twice.returns('base_filename')
      end

      it 'should remove the suffix from the only package file' do
        package.expects(:chunk_suffixes=).never
        FileUtils.expects(:mv).with(
          File.join(Backup::Config.tmp_path, 'base_filename-aa'),
          File.join(Backup::Config.tmp_path, 'base_filename')
        )
        splitter.send(:after_packaging)
      end
    end
  end # describe '#after_packaging'

  describe '#chunk_suffixes' do
    before do
      splitter.expects(:chunks).returns(
        ['/path/to/file.tar-aa', '/path/to/file.tar-ab']
      )
    end

    it 'should return an array of chunk suffixes' do
      splitter.send(:chunk_suffixes).should == ['aa', 'ab']
    end
  end

  describe '#chunks' do
    before do
      splitter.instance_variable_set(:@package, package)
      package.expects(:basename).returns('base_filename')
      FileUtils.unstub(:touch)
    end

    it 'should return a sorted array of chunked file paths' do
      Dir.mktmpdir do |dir|
        Backup::Config.expects(:tmp_path).returns(dir)
        FileUtils.touch(File.join(dir, 'base_filename-aa'))
        FileUtils.touch(File.join(dir, 'base_filename-ab'))

        splitter.send(:chunks).should == [
          File.join(dir, 'base_filename-aa'),
          File.join(dir, 'base_filename-ab')
        ]
      end
    end
  end

end
