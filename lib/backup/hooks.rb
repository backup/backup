
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
        Logger.message "Performing Before Hook"
        @before_proc.call(model)
        Logger.message "Before Hook Completed Successfully"
      rescue => err
        raise Errors::Hooks::BeforeHookError.wrap(
          err, "Before Hook Failed!"
        )
      end
    end

    def after!
      begin
        Logger.message "Performing After Hook"
        @after_proc.call(model)
        Logger.message "After Hook Completed Successfully"
      rescue => err
        raise Errors::Hooks::AfterHookError.wrap(
          err, "After Hook Failed!"
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
