# encoding: utf-8

module Backup
  module Syncer
    class Base
      include Backup::CLI
      include Backup::Configuration::Helpers
    end
  end
end
