# frozen_string_literal: true

module Ask
  # Decision primitives — the vocabulary for typed questions that return structured
  # answers with calibrated probabilities. The three types mirror TypeSafe's System
  # One API: Choice, Score, and Noul.
  #
  # These are vendor-neutral value objects in ask-core so that every gem in the
  # ecosystem can speak decisions without depending on a specific provider gem.
  #
  # @example A Choice question
  #   Ask::Decision::Choice.new(
  #     instructions: "Which team should handle this?",
  #     criteria: { billing: "Payment issues", technical: "Bugs or outages" }
  #   )
  #
  # @example A Noul question
  #   Ask::Decision::Noul.new(
  #     instructions: "Does this message express urgency?"
  #   )
  #
  module Decision
    # A Choice question: pick one option from a defined set.
    #
    # @attr_reader instructions [String] the question to evaluate
    # @attr_reader criteria [Hash{String => String}] option → rubric description
    class Choice
      attr_reader :instructions, :criteria

      def initialize(instructions:, criteria:)
        @instructions = instructions
        @criteria = criteria.freeze
        freeze
      end

      def type = :choice

      # Wire format for a single question entry.
      def to_h
        { type: "choice", instructions: instructions, criteria: criteria }
      end
    end

    # A Score question: rate the state on ordered, descriptive levels.
    #
    # @attr_reader instructions [String] what to rate
    # @attr_reader criteria [Array<String>] ordered level descriptions (≥2)
    class Score
      attr_reader :instructions, :criteria

      def initialize(instructions:, criteria:)
        @instructions = instructions
        @criteria = Array(criteria).freeze
        raise ArgumentError, "Score criteria must have at least 2 levels" if @criteria.size < 2
        freeze
      end

      def type = :score

      def to_h
        { type: "score", instructions: instructions, criteria: criteria }
      end
    end

    # A Noul question: is this statement true? Returns a probability (0–1).
    #
    # @attr_reader instructions [String] the yes/no question
    # @attr_reader criteria [Hash, nil] optional { "true" => "...", "false" => "..." }
    class Noul
      attr_reader :instructions, :criteria

      def initialize(instructions:, criteria: nil)
        @instructions = instructions
        @criteria = criteria&.freeze
        freeze
      end

      def type = :noul

      def to_h
        h = { type: "noul", instructions: instructions }
        h[:criteria] = criteria if criteria
        h
      end
    end
  end
end
