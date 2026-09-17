# frozen_string_literal: true

module Ask
  # Typed answer objects returned by a DecisionProvider. Each answer type
  # carries the raw values plus convenience helpers for common patterns.
  #
  # @example Reading a Choice answer
  #   result = Ask.decide(state: "...", decisions: { "route" => choice_q })
  #   result["route"].choice        # => "technical"
  #   result["route"].confidence   # => 0.84
  #   result["route"].ranked       # => [["technical", 0.84], ["billing", 0.12], ...]
  #   result["route"].confident?(0.7)  # => true
  #
  module DecisionResult
    # A single answer from a decision call.
    module Answer
      # @return [String] the question id
      attr_reader :id

      # @return [Float] raw latency of this answer in seconds (set by provider)
      attr_reader :latency

      def initialize(id:, latency: nil)
        @id = id
        @latency = latency
      end
    end

    # Choice answer: the picked option, full probability distribution, and confidence.
    class ChoiceAnswer
      include Answer

      attr_reader :choice, :probabilities, :confidence, :ranked

      def initialize(id:, choice:, probabilities:, confidence: nil, latency: nil)
        super(id: id, latency: latency)
        @choice = choice
        @probabilities = probabilities.freeze
        @confidence = confidence
        @ranked = probabilities.sort_by { |_, v| -v }.freeze
        freeze
      end

      def type = :choice

      # The option with the highest probability.
      def best = ranked.first

      # Whether the confidence meets a threshold. For Choice answers this uses
      # the calibrated confidence value.
      def confident?(threshold = 0.7)
        return false if confidence.nil?
        confidence >= threshold
      end
    end

    # Score answer: a probability-weighted position across your levels.
    class ScoreAnswer
      include Answer

      attr_reader :score, :legend, :probabilities, :confidence, :ranked

      def initialize(id:, score:, legend:, probabilities:, confidence: nil, latency: nil)
        super(id: id, latency: latency)
        @score = score
        @legend = legend.freeze
        @probabilities = probabilities.freeze
        @confidence = confidence
        @ranked = probabilities.sort_by { |_, v| -v }.freeze
        freeze
      end

      def type = :score

      def best = ranked.first

      def confident?(threshold = 0.7)
        return false if confidence.nil?
        confidence >= threshold
      end

      # The probability-weighted expectation across levels (same as .score).
      def expected = score
    end

    # Noul answer: the probability that the statement is true (0–1).
    # Noul answers do NOT carry a separate confidence value.
    class NoulAnswer
      include Answer

      attr_reader :noul

      def initialize(id:, noul:, latency: nil)
        super(id: id, latency: latency)
        @noul = noul
        freeze
      end

      def type = :noul

      # Noul has no confidence field, so confidence-gating uses the value's
      # distance from 0.5. Returns the distance; 0 means fully uncertain,
      # 0.5 means fully certain.
      def strength
        (noul - 0.5).abs
      end

      # Gate a noul answer against a threshold. A noul > 0.5 is a "yes",
      # and this method checks both the direction and the strength.
      #
      # @param threshold [Float] minimum strength (distance from 0.5) to pass
      # @return [Boolean]
      def confident?(threshold = 0.3)
        strength >= threshold
      end

      def yes?  = noul >= 0.5
      def no?   = noul < 0.5
    end

    # Aggregate result from a batch of decisions. Answers are accessed by id.
    class Batch
      include Enumerable

      attr_reader :answers, :usage, :model, :latency, :min_confidence

      def initialize(answers:, model: nil, usage: nil, latency: nil)
        @answers = answers.freeze
        @model = model
        @usage = usage
        @latency = latency
        @min_confidence = @answers.values
          .select { |a| a.respond_to?(:confidence) && !a.confidence.nil? }
          .map(&:confidence)
          .min
        freeze
      end

      # Access an answer by id.
      def [](id)
        @answers[id.to_s]
      end

      def each(&block)
        @answers.each_value(&block)
      end

      # Whether every choice/score answer meets a confidence threshold.
      def all_confident?(threshold = 0.7)
        return true if @answers.empty?
        @answers.values.all? do |a|
          !a.respond_to?(:confidence) || a.confidence.nil? || a.confidence >= threshold
        end
      end

      def to_h
        @answers.transform_values { |a| a.respond_to?(:to_h) ? a.to_h : a }
      end
    end
  end
end
