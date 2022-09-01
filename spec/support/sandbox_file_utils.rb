#
# Provides the ability to perform +FileUtils+ actions, while restricting
# any destructive actions outside of the specified +sandbox_path+.
#
# == Usage
#
# To enable protection:
#
#   require 'sandbox_file_utils'
#
#   SandboxFileUtils.activate!
#   SandboxFileUtils.sandbox_path = 'my_sandbox'
#   # or
#   # SandboxFileUtils.activate! 'my_sandbox'
#
#   FileUtils.touch 'my_sandbox/file' # => OK
#   FileUtils.touch 'file' # => Error
#
# To disable protection:
#
#   SandboxFileUtils.deactivate!
#   FileUtils.touch 'my_sandbox/file' # => OK
#   FileUtils.touch 'file' # => OK
#
#   # When re-activating, the currently set +sandbox_path+ will still be in effect.
#   SandboxFileUtils.activate!
#   FileUtils.touch 'my_sandbox/file' # => OK
#   FileUtils.touch 'file' # => Error
#
# When disabling protection, you may also pass +:noop+ which will restore
# +::FileUtils+ to +FileUtils::NoWrite+.
#
#   SandboxFileUtils.deactivate!(:noop)
#   FileUtils.touch 'file' # => OK
#   File.exist? 'file' # => false
#
# The +sandbox_path+ may be changed at any time.
#
#   require 'sandbox_file_utils'
#
#   SandboxFileUtils.activate! 'my_sandbox'
#   FileUtils.touch 'my_sandbox/file' # => OK
#   FileUtils.touch 'other_path/file' # => Error
#
#   SandboxFileUtils.sandbox_path = 'other_path'
#   FileUtils.touch 'other_path/file' # => OK
#   FileUtils.touch 'my_sandbox/file' # => Error
#
# This module may also be used directly, with no activation required.
#
#   require 'sandbox_file_utils'
#
#   SandboxFileUtils.sandbox_path = 'my_sandbox'
#   SandboxFileUtils.touch 'my_sandbox/file' # => OK
#   SandboxFileUtils.touch 'other_path/file' # => Error
#
# == Module Functions
#
# The following are accessible and operate without restriction:
#
#   pwd (alias: getwd)
#   cd (alias: chdir)
#   uptodate?
#   compare_file (alias: identical? cmp)
#   compare_stream
#
# The following are accessible, but will not allow operations on files or
# directories outside of the +sandbox_path+.
#
# No links may be created within the +sandbox_path+ to outside files or
# directories. Files may be copied from outside into the +sandbox_path+.
#
# Operations not permitted will raise an +Error+.
#
#   mkdir
#   mkdir_p (alias: makedirs mkpath)
#   rmdir
#   ln (alias: link)
#   ln_s (alias: symlink)
#   ln_sf
#   cp (alias: copy)
#   cp_r
#   mv (alias: move)
#   rm (alias: remove)
#   rm_f (alias: safe_unlink)
#   rm_r
#   rm_rf (alias: rmtree)
#   install
#   chmod
#   chmod_R
#   chown
#   chown_R
#   touch
#
# The following low-level methods, normally available through +FileUtils+,
# will remain private and not be available:
#
#   copy_entry
#   copy_file
#   copy_stream
#   remove_entry_secure
#   remove_entry
#   remove_file
#   remove_dir
#
require "fileutils"
module SandboxFileUtils
  class Error < StandardError; end
  class << self
    include FileUtils
    RealFileUtils = FileUtils

    # Sets the root path where restricted operations will be allowed.
    #
    # This is evaluated at the time of each method call,
    # so it may be changed at any time.
    #
    # This may be a relative or absolute path. If relative, it will be
    # based on the current working directory.
    #
    # The +sandbox_path+ itself may be created or removed by this module.
    # Missing parent directories in this path may be created using +mkdir_p+,
    # but you would not be able to remove them.
    #
    #   FileUtils.sandbox_path = 'my/sandbox'
    #   FileUtils.mkdir 'my'           # => will raise an Error
    #   FileUtils.mkdir_p 'my/sandbox' # => creates both directories
    #   FileUtils.rmdir 'my/sandbox'   # => removes 'sandbox'
    #   FileUtils.rmdir 'my'           # => will raise an Error
    #   # This would work in 1.9.x, but the :parents option is currently broken.
    #   # FileUtils.rmdir 'my/sandbox', parents: true
    #
    # An +Error+ will be raised if any module functions are called without this set.
    attr_accessor :sandbox_path

    # Returns whether or not SandboxFileUtils protection for +::FileUtils+ is active.
    def activated?
      ::FileUtils == self
    end

    # Enables this module so that all calls to +::FileUtils+ will be protected.
    #
    # If +path+ is given, it will be used to set +sandbox_path+ - regardless of
    # whether or not this call returns +true+ or +false+.
    #
    # Returns +true+ if activation occurs.
    # Returns +false+ if +activated?+ already +true+.
    def activate!(path = nil)
      path = path.to_s
      self.sandbox_path = path unless path.empty?

      return false if activated?
      Object.send(:remove_const, :FileUtils)
      Object.const_set(:FileUtils, self)
      true
    end

    # Disables this module by restoring +::FileUtils+ to the real +FileUtils+ module.
    #
    # When deactivated, +sandbox_path+ will remain set to it's current value.
    # Therefore, if +activate!+ is called again, +sandbox_path+ will still be set.
    #
    # By default, +deactivate!+ will restore +::FileUtils+ to the fully functional
    # +FileUtils+ module. If +type+ is set to +:noop+, it will restore +::FileUtils+
    # to +FileUtils::NoWrite+, so that any method calls to +::FileUtils+ will be +noop+.
    #
    # Returns +true+ if deactivation occurs.
    # Returns +false+ if +activated?+ is already +false+.
    def deactivate!(type = :real)
      return false unless activated?

      Object.send(:remove_const, :FileUtils)
      if type == :noop
        Object.const_set(:FileUtils, RealFileUtils::NoWrite)
      else
        Object.const_set(:FileUtils, RealFileUtils)
      end
      true
    end

    %w[
      pwd getwd cd chdir uptodate? compare_file identical? cmp
      compare_stream
    ].each do |name|
      public :"#{ name }"
    end

    %w[
      mkdir mkdir_p makedirs mkpath rmdir rm remove rm_f safe_unlink rm_r
      rm_rf rmtree touch
    ].each do |name|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{name}(list, **options)
          protect!(list)
          super
        end
      EOS
    end

    %w[cp copy cp_r install].each do |name|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{name}(src, dest, **options)
          protect!(dest)
          super
        end
      EOS
    end

    %w[ln link ln_s symlink ln_sf mv move].each do |name|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{name}(src, dest, **options)
          protect!(src)
          super
        end
      EOS
    end

    %w[chmod chmod_R].each do |name|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{name}(mode, list, **options)
          protect!(list)
          super
        end
      EOS
    end

    %w[chown chown_R].each do |name|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{name}(user, group, list, **options)
          protect!(list)
          super
        end
      EOS
    end

    private

    def protect!(list)
      list = Array(list).flatten.map { |p| File.expand_path(p) }
      path = current_sandbox_path + "/"
      unless list.all? { |p| p.start_with?(path) || p == path.chomp("/") }
        raise Error, <<-EOS.gsub(/^ +/, ""), caller(1)
          path(s) outside of the current sandbox path were detected.
          sandbox_path: #{path}
          path(s) for the current operation:
          #{list.join($/)}
        EOS
      end
    end

    def current_sandbox_path
      path = sandbox_path.to_s.chomp("/")
      raise Error, "sandbox_path must be set" if path.empty?
      File.expand_path(path)
    end
  end
end
