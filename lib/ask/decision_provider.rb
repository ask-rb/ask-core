# frozen_string_literal: true

module Ask
  # Abstract base class for decision providers. Mirrors Ask::Provider but for
  # structured decisions (Choice / Score / Noul) instead of text generation.
  #
  # Subclasses implement {#evaluate} and register via {.register}. The active
  # provider is resolved via {.resolve}.
  #
  # @example Registering a provider
  #   Ask::DecisionProvider.register(:typesafe, Ask::Decisions::Typesafe)
  #
  # @example Resolving and using a provider
  #   provider = Ask::DecisionProvider.resolve(:typesafe)
  #   result = provider.evaluate(state: "...", decisions: { "q" => choice_q })
  #
  class DecisionProvider
    REGISTRY_MUTEX = Mutex.new
    private_constant :REGISTRY_MUTEX

    # @return [Object] provider configuration
    attr_reader :config

    def initialize(config = {})
      @config = config
    end

    # Evaluate a state against a map of decisions and return a Result::Batch.
    #
    # @param state [String, Hash, Array] the content to evaluate
    # @param decisions [Hash{String => Decision::Choice|Decision::Score|Decision::Noul}]
    #   map of id → question
    # @param model [String, nil] model to use (provider-specific)
    # @return [DecisionResult::Batch]
    # @raise [NotImplementedError] in subclasses that don't implement this
    def evaluate(state:, decisions:, model: nil)
      raise NotImplementedError, "#{self.class} must implement #evaluate"
    end

    # --- Slug / name ---

    def slug  = self.class.slug
    def name  = self.class.name

    # --- Registry (class-level) ---

    class << self
      def register(name, provider_class)
        REGISTRY_MUTEX.synchronize { registry[name.to_sym] = provider_class }
      end

      def resolve(name)
        REGISTRY_MUTEX.synchronize do
          registry[name.to_sym] || raise(Ask::UnknownProvider,
            "Unknown decision provider: #{name.inspect}. " \
            "Available: #{registry.keys.join(', ')}")
        end
      end

      def providers
        REGISTRY_MUTEX.synchronize { registry.dup }
      end

      def clear_providers!
        REGISTRY_MUTEX.synchronize { @registry = {} }
      end

      def slug
        name.split("::").last.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
      end

      def name
        to_s.split("::").last
      end

      private

      def registry
        @registry ||= {}
      end
    end
  end
end
