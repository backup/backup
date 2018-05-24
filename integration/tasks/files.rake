# encoding: utf-8

require File.expand_path("../fileset_builder", __FILE__)

directory "tmp"
directory "tmp/test_data"

namespace :integration do
  desc "Create test files"
  task files: ["tmp", "tmp/test_data"] do
    fb = FilesetBuilder.new
    test_dirs = { "dir_a" => 3, "dir_b" => 3, "dir_c" => 3, "dir_d" => 1 }
    test_dirs.each do |dir, total|
      fb.create(File.join("tmp", "test_data"), dir, total, 1)
    end
  end
end
