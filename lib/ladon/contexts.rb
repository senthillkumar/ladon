module Ladon
  # A Context is a fancy name for just any Ruby object with an idiomatic name.
  # In Ladon, Contexts are used as the primary bridge between a ModelAutomation and
  # the underlying model it is working through.
  #
  # The idea is that the methods defined on the model describe features of the
  # software being modeled. The implementations of those methods then are used
  # to describe how to automate the consumption of those features under various
  # contexts. Hence, 'Context'.
  class Context
    attr_reader :name, :context_obj

    def initialize(name, context_obj)
      @name = name
      @context_obj = context_obj
    end
  end

  # Module for anything that has contexts
  module HasContexts
    def contexts
      @contexts
    end

    def contexts=(contexts)
      raise StandardError, 'Not a hash!' unless contexts.is_a?(Hash)
      @contexts = {} if @contexts.nil?
      @contexts.merge!(contexts)
      contexts.each do |name, ctx|
        raise StandardError, "Invalid context detected!" unless ctx.is_a?(Ladon::Context)
        instance_variable_set("@#{ctx.name}", ctx.context_obj)
      end
    end

    def context(name)
      @contexts[name]
    end
  end
end