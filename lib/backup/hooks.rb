
# encoding: utf-8

module Backup
  class Hooks
    include Backup::CLI::Helpers

    ##
    # Stores a block to be run before the backup
    attr_accessor :before_proc

    ##
    # Stores a block to be run before the backup
    attr_accessor :after_proc

    ##
    # The model
    attr_reader :model

    def initialize(model, &block)
      @model = model
      @before_proc = Proc.new { } # noop
      @after_proc = Proc.new { } # noop
      instance_eval(&block) if block_given?
    end

    def before(&code)
      @before_proc = code
    end

    def after(&code)
      @after_proc = code
    end

    def before!
      begin
        @before_proc.call(model)
      rescue => err
        raise Errors::Hooks::BeforeHookError.wrap(
          err, 'Error in before hook'
        )
      end
    end

    def after!
      begin
        @after_proc.call(model)
      rescue => err
        raise Errors::Hooks::AfterHookError.wrap(
          err, 'Error in after hook'
        )
      end
    end

    def perform!(hook)
      case hook
      when :before
        before!
      when :after
        after!
      end
    end
  end
end
