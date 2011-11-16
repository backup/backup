# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'

describe Backup::Splitter do
  let(:model)    { mock("Backup::Model")       }
  let(:splitter) { Backup::Splitter.new(model) }

  before do
    splitter.stubs(:chunks).returns([
      "/some/file.tar.gz.enc-ad",
      "/some/file.tar.gz.enc-ac",
      "/some/file.tar.gz.enc-ab",
      "/some/file.tar.gz.enc-aa",
    ])
  end

  describe "#chunk_suffixes" do
    it "should return an array of chunk suffixes (ordered in alphabetical order)" do
      splitter.send(:chunk_suffixes).should == ["aa", "ab", "ac", "ad"]
    end
  end

  describe "#bytes_representation_of" do
    it "should convert megabytes to bytes" do
      splitter.send(:bytes_representation_of, 50).should == 52428800
    end
  end

  describe "#split!" do
    before do
      model.stubs(:file).returns("/some/file.tar.gz.enc")
    end

    [nil, true, false, "123", :sym].each do |value|
      it "should not split: chunk_size must be an integer" do
        model.stubs(:chunk_size).returns(value)

        File.expects(:size).never
        splitter.expects(:bytes_representation_of).never
        splitter.expects(:run).never
        splitter.split!
      end
    end

    it "should not split: chunk size is 300mb, file is 300mb" do
      File.expects(:size).with(model.file).returns(52428800) # 300mb
      model.stubs(:chunk_size).returns(300)

      splitter.expects(:run).never
      splitter.split!
    end

    it "should not split: chunk size is 300mb, file size is 200mb" do
      File.expects(:size).with(model.file).returns(209715200) # 200mb
      model.stubs(:chunk_size).returns(300)

      splitter.expects(:run).never
      splitter.split!
    end

    it "should split: chunk size is 300mb, file size is 400mb" do
      File.expects(:size).with(model.file).returns(419430400) # 400mb
      model.stubs(:chunk_size).returns(300)

      splitter.expects(:utility).with(:split).returns("split")
      splitter.expects(:run).with("split -b 300m '/some/file.tar.gz.enc' '/some/file.tar.gz.enc-'")
      splitter.split!
    end
  end
end