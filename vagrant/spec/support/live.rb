# encoding: utf-8

module BackupSpec
  file = File.expand_path('../../live.yml', __FILE__)
  LIVE = File.exist?(file) ? YAML.load_file(file) : Hash.new {|h,k| h.dup }
end
