# encoding: utf-8

module Backup
  class Archive
    class Error < Backup::Error; end

    include Backup::Utilities::Helpers
    attr_reader :name, :options

    ##
    # Adds a new Archive to a Backup Model.
    #
    #     Backup::Model.new(:my_backup, 'My Backup') do
    #       archive :my_archive do |archive|
    #         archive.add 'path/to/archive'
    #         archive.add '/another/path/to/archive'
    #         archive.exclude 'path/to/exclude'
    #         archive.exclude '/another/path/to/exclude'
    #       end
    #     end
    #
    # All paths added using `add` or `exclude` will be expanded to their
    # full paths from the root of the filesystem. Files will be added to
    # the tar archive using these full paths, and their leading `/` will
    # be preserved (using tar's `-P` option).
    #
    #     /path/to/pwd/path/to/archive/...
    #     /another/path/to/archive/...
    #
    # When a `root` path is given, paths to add/exclude are taken as
    # relative to the `root` path, unless given as absolute paths.
    #
    #     Backup::Model.new(:my_backup, 'My Backup') do
    #       archive :my_archive do |archive|
    #         archive.root '~/my_data'
    #         archive.add 'path/to/archive'
    #         archive.add '/another/path/to/archive'
    #         archive.exclude 'path/to/exclude'
    #         archive.exclude '/another/path/to/exclude'
    #       end
    #     end
    #
    # This directs `tar` to change directories to the `root` path to create
    # the archive. Unless paths were given as absolute, the paths within the
    # archive will be relative to the `root` path.
    #
    #     path/to/archive/...
    #     /another/path/to/archive/...
    #
    # For absolute paths added to this archive, the leading `/` will be
    # preserved. Take note that when archives are extracted, leading `/` are
    # stripped by default, so care must be taken when extracting archives with
    # mixed relative/absolute paths.
    def initialize(model, name, &block)
      @model   = model
      @name    = name.to_s
      @options = {
        :sudo        => false,
        :root        => false,
        :paths       => [],
        :excludes    => [],
        :tar_options => ''
      }
      DSL.new(@options).instance_eval(&block)
    end

    def perform!
      Logger.info "Creating Archive '#{ name }'..."

      path = File.join(Config.tmp_path, @model.trigger, 'archives')
      FileUtils.mkdir_p(path)

      pipeline = Pipeline.new
      with_files_from(paths_to_package) do |files_from|
        pipeline.add(
          "#{ tar_command } #{ tar_options } -cPf -#{ tar_root } " +
          "#{ paths_to_exclude } #{ files_from }",
          tar_success_codes
        )

        extension = 'tar'
        @model.compressor.compress_with do |command, ext|
          pipeline << command
          extension << ext
        end if @model.compressor

        pipeline << "#{ utility(:cat) } > " +
            "'#{ File.join(path, "#{ name }.#{ extension }") }'"
        pipeline.run
      end

      if pipeline.success?
        Logger.info "Archive '#{ name }' Complete!"
      else
        raise Error, "Failed to Create Archive '#{ name }'\n" +
            pipeline.error_messages
      end
    end

    private

    def tar_command
      tar = utility(:tar)
      options[:sudo] ? "#{ utility(:sudo) } -n #{ tar }" : tar
    end

    def tar_root
      options[:root] ? " -C '#{ File.expand_path(options[:root]) }'" : ''
    end

    def paths_to_package
      options[:paths].map {|path| prepare_path(path) }
    end

    def with_files_from(paths)
      tmpfile = Tempfile.new('backup-archive-paths')
      paths.each {|path| tmpfile.puts path }
      tmpfile.close
      yield "-T '#{ tmpfile.path }'"
    ensure
      tmpfile.delete
    end

    def paths_to_exclude
      options[:excludes].map {|path|
        "--exclude='#{ prepare_path(path) }'"
      }.join(' ')
    end

    def prepare_path(path)
      options[:root] ? path : File.expand_path(path)
    end

    def tar_options
      args = options[:tar_options]
      gnu_tar? ? "--ignore-failed-read #{ args }".strip : args
    end

    def tar_success_codes
      gnu_tar? ? [0, 1] : [0]
    end

    class DSL
      def initialize(options)
        @options = options
      end

      def use_sudo(val = true)
        @options[:sudo] = val
      end

      def root(path)
        @options[:root] = path
      end

      def add(path)
        @options[:paths] << path
      end

      def exclude(path)
        @options[:excludes] << path
      end

      def tar_options(opts)
        @options[:tar_options] = opts
      end
    end

  end
end
