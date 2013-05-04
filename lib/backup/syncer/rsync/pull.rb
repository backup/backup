# encoding: utf-8

module Backup
  module Syncer
    module RSync
      class Pull < Push

        def perform!
          log!(:started)
          write_password_file!

          create_dest_path!
          run("#{ rsync_command } #{ host_options }#{ paths_to_pull } " +
              "'#{ dest_path }'")

          log!(:finished)
        ensure
          remove_password_file!
        end

        private

        ##
        # Returns the syntax for pulling multiple paths from the remote host.
        # e.g.
        #   rsync -a -e "ssh -p 22" host:'path1' :'path2' '/dest'
        #   rsync -a rsync_user@host::'modname/path1' ::'modname/path2' '/dest'
        #
        # Remove any preceeding '~/', since these paths are on the remote.
        # Also remove any trailing `/`, since we don't want rsync's
        # "trailing / on source directories" behavior.
        def paths_to_pull
          sep = mode == :ssh ? ':' : '::'
          directories.map {|dir|
            "#{ sep }'#{ dir.sub(/^~\//, '').sub(/\/$/, '') }'"
          }.join(' ').sub(/^#{ sep }/, '')
        end

        # Expand path, since this is local and shell-quoted.
        def dest_path
          @dest_path ||= File.expand_path(path)
        end

        def create_dest_path!
          FileUtils.mkdir_p dest_path
        end

        attr_deprecate :additional_options, :version => '3.2.0',
                       :message => 'Use #additional_rsync_options instead.',
                       :action => lambda {|klass, val|
                         klass.additional_rsync_options = val
                       }

        attr_deprecate :username, :version => '3.2.0',
                       :message => 'Use #ssh_user instead.',
                       :action => lambda {|klass, val|
                         klass.ssh_user = val
                       }
        attr_deprecate :password, :version => '3.2.0',
                       :message => 'Use #rsync_password instead.',
                       :action => lambda {|klass, val|
                         klass.rsync_password = val
                       }
        attr_deprecate :ip, :version => '3.2.0',
                       :message => 'Use #host instead.',
                       :action => lambda {|klass, val|
                         klass.host = val
                       }
      end
    end
  end
end
