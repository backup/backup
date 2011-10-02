require "rspec"
require 'popen4'

require File.dirname(__FILE__) + '/spec_helper'
module Backup
  module Storage
    class Dummy < Base
      def local_path
        "/tmp/dummy/path"
      end

      def local_file
        "dummy.file"
      end

      def remote_path
        "backups/myapp"
      end

      def remote_file
        "dummy.file"
      end
    end
  end
end

describe "Storage File Splitter" do

  let(:splitter) do
    dummy = Backup::Storage::Dummy.new
    dummy.extend(Backup::Splitter)
  end

  it "should split into chunks of configured size" do
    test_split 230, 600, ["#{splitter_file_location}-0", "#{splitter_file_location}-1", "#{splitter_file_location}-2"]
    test_split 350, 600, ["#{splitter_file_location}-0", "#{splitter_file_location}-1"]
    test_split 350, 100, ["#{splitter_file_location}-0"]
  end

  it "should not split by default" do
    splitter.expects(:run).never
    File.expects(:size?).never
    splitter.split!
    splitter.local_chunks.size.should == 1
    splitter.local_chunks.first.should == splitter_file_location
  end

  it "should not split with missing file spec" do
    splitter.split_archive_file = true
    Backup::Logger.expects(:error).once
    splitter.split!
  end

  def test_split(chunk_size, file_size, expected_chunks)
    set_split_configuration(chunk_size)
    set_split_expectations(chunk_size, file_size)
    splitter.split!
    assert_local_chunks(expected_chunks)
    splitter.number_of_archive_chunks.should == expected_chunks.size
  end

  def set_split_configuration(chunk_size)
    splitter.split_archive_file = true
    splitter.archive_file_chunk_size = chunk_size
  end

  def set_split_expectations(chunk_size, file_size)
    File.expects(:size?).with(splitter_file_location).returns(file_size * 1000 * 1000)
    splitter.expects(:run).once.with("split -b #{chunk_size}MB -d #{splitter_file_location} #{splitter_file_location}-")
  end

  def assert_local_chunks(expected_chunks)
    splitter.local_chunks.should be_kind_of Array
    splitter.local_chunks.size.should == expected_chunks.size
    expected_chunks.each do |expected_chunk|
      splitter.local_chunks.should include expected_chunk
    end
  end

  def splitter_file_location
    "#{splitter.local_path + '/' + splitter.local_file}"
  end

end