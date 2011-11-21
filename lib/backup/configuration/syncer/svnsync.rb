# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      class SVNSync < Base
        class << self

          attr_accessor :protocol, :username, :password, :host, :port, :repo_path, :path

        end
      end
    end
  end
end
