module Ladon
  module Modeler
    # Used to model when and how modeled software can execute a change of State.
    #
    # @attr_reader [Hash<Object, Object>] metadata Arbitrary key:value pairs associated with the transition.
    # @attr_reader [Boolean] target_loaded True if the transition's target state type loader has been run.
    class Transition
      attr_reader :metadata, :target_loaded
      alias target_loaded? target_loaded

      # Standard key to be used to map transition target state name metadata
      TARGET_NAME_KEY = :target_name

      # Create a new Transition instance, optionally specifying a block to customize the transition.
      #
      # @yield [new_transition] The transition instance being created.
      def initialize
        @when_blocks = []
        @by_blocks = []
        @metadata = {}

        @identifier = nil
        @target_type = nil
        @target_loaded = false

        yield(self) if block_given?
      end

      # Define metadata associated with this transition.
      # Overwrites any existing metadata associated with the given +key+.
      #
      # @param [Object] key The key to associate to a value.
      # @param [Object] value The value to associate with the given +key+.
      #
      # @return [Object] The +value+ argument provided to this method.
      def meta(key, value)
        @metadata[key] = value
      end

      # Retrieves the metadata associated with the given +key+.
      #
      # @param key The key to look up in the metadata map.
      # @return [Object] The value currently mapped to the given +key+.
      def meta_for(key)
        @metadata[key]
      end

      # Use this method to define a block that will return true when this transition is valid to execute.
      # If *any* block defined in this manner returns true, the transition will be considered executable.
      # These blocks are leveraged by +valid_for?+ to determine if this transition is available.
      #
      # @raise [BlockRequiredError] if called without a block.
      #
      # @return [Proc] The block that was given to this method.
      def when(&block)
        raise BlockRequiredError, 'Required block was not provided!' unless block_given?
        @when_blocks << block
      end

      # Use this method to define a block that will be called when executing this transition.
      # Any number of blocks may be specified in this manner. These blocks will be evaluated in the order
      # they were defined on the transition. These blocks are leveraged by +make_transition+ to execute this transition.
      #
      # @raise [BlockRequiredError] if called without a block.
      #
      # @return [Proc] The block that was given to this method.
      def by(&block)
        raise BlockRequiredError, 'Required block was not provided!' unless block_given?
        @by_blocks << block
      end

      # Determine if this transition is valid given the +current_state+. A
      # transition is valid if it has no +when_blocks+, or at least one of its
      # +when_blocks+ returns true.
      #
      # @param [Ladon::Modeler::State] current_state Instance of current state to validate against.
      # @param [KeywordArguments] **kwargs Arbitrary named arguments that will be provided
      #   to the 'when' method
      # @return [Boolean] True if the transition is found to be currently valid, false otherwise.
      def valid_for?(current_state, **kwargs)
        @when_blocks.empty? || @when_blocks.any? do |condition|
          if kwargs.empty?
            condition.call(current_state) == true
          else
            condition.call(current_state, **kwargs) == true
          end
        end
      end

      # Execute this transition. If the target state has not been loaded, this method will load it.
      #
      # *Warning:* the ability to specify multiple "by" blocks is primarily a convenience.
      # Since *all* by blocks will be executed in context of the +current_state+, only the
      # *last* by block should actually cause the state change (otherwise, the +current_state+
      # may be invalid when given to subsequent "by" blocks.)
      #
      # @param [Ladon::Modeler::State] current_state Instance of current state to execute against.
      # @param [KeywordArguments] **kwargs Arbitrary named arguments that will be provided
      #   to the 'by' method
      # @return [Array<Object>] An array containing the return value of each "by" block.
      def execute(current_state, **kwargs)
        load_target
        @by_blocks.map do |executor|
          if kwargs.empty?
            executor.call(current_state)
          else
            executor.call(current_state, **kwargs)
          end
        end
      end

      # The +&block+ given to this method will be used as the routine that should load
      # the transition's target state type into the Ruby interpreter.
      #
      # Running this block should guarantee that the return value of +target_type+
      # will be resolvable and not result in a reference error.
      #
      # @raise [BlockRequiredError] if called without a block.
      # @raise [AlreadyLoadedError] if called when the target state type has already been loaded.
      def target_loader(&block)
        raise BlockRequiredError, 'Required block was not provided!' unless block_given?
        raise AlreadyLoadedError, 'Already loaded!' if target_loaded?
        @loader = block
      end

      # Runs the +@loader+ Proc that was specified via +target_loader+.
      # Short circuits execution if the target state type is already loaded.
      #
      # @raise [NoMethodError] if called without a +@loader+ defined.
      # @return [Boolean] True if the target state type is loaded.
      def load_target
        return true if target_loaded?
        @loader.call
        @target_loaded = true
      end

      # The +&block+ given to this method will be used as the routine that can be run
      # to get a reference to the target state type's Class.
      #
      # @raise [BlockRequiredError] if called without a block.
      # @raise [AlreadyLoadedError] if called when the target state type has already been loaded.
      def target_identifier(&block)
        raise BlockRequiredError, 'Required block was not provided!' unless block_given?
        raise AlreadyLoadedError, 'Already loaded!' if target_loaded?
        @identifier = block
      end

      # Track the given argument as metadata on this transition.
      # If +target_identifier+ has not been set, this will automatically call it such that the identifier simply
      # looks up the class with the given name.
      #
      # @param [String] name The name of the transition's target type.
      def target_name=(name)
        meta(TARGET_NAME_KEY, name)
        target_identifier { Object.const_get(name) } if @identifier.nil?
      end

      # Get the metadata mapping to the standard target name key.
      #
      # @return Whatever metadata is associated with the +TARGET_NAME_KEY+. This _should_ map to a class. Will be +nil+
      #   if no metadata exists for this key.
      def target_name
        meta_for(TARGET_NAME_KEY)
      end

      # Returns a reference to the state type of this transition's target.
      # Calls the identifier block specified via +target_identifier+ to
      # ensure that the target is loaded before exposing the bare reference to it.
      #
      # @return [Class] Reference to the target State class type.
      def target_type
        load_target
        @target_type ||= @identifier.call
      end
    end
  end
end
