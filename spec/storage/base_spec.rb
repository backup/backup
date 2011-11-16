# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Storage::Base do
  let(:base) { Backup::Storage::Base.new }

  it do
    storage_object = mock
    Backup::Storage::Object.expects(:new).with('Base').returns(storage_object)
    storage_object.stubs(:load).returns([])
    storage_object.expects(:write)
    base.keep = 1
    base.cycle!
  end

  it do
    base.keep = 3
    storage_object = mock
    objects = %w[1 2 3 4].map { Backup::Storage::Base.new }

    Backup::Storage::Object.expects(:new).with('Base').returns(storage_object)
    storage_object.stubs(:load).returns(objects)
    storage_object.expects(:write)
    Backup::Storage::Base.any_instance.expects(:remove!).times(2)

    base.cycle!
  end

  it do
    base = Backup::Storage::Base.new
    base.chunk_suffixes = ["aa", "ab", "ac", "ad", "ae"]
    base.stubs(:filename).returns("file.tar")
    base.chunks.should == [
      "#{base.filename}-aa",
      "#{base.filename}-ab",
      "#{base.filename}-ac",
      "#{base.filename}-ad",
      "#{base.filename}-ae",
    ]

    base.chunk_suffixes.should == ["aa", "ab", "ac", "ad", "ae"]
  end
end
