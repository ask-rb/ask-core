# frozen_string_literal: true

require "json"
require "net/http"
require "time"

module Ask
  # Model metadata: capabilities, pricing, context window, modalities.
  # Immutable value object representing a single model entry.
  class ModelInfo
    # @return [String] model identifier (e.g. "gpt-4o")
    attr_reader :id

    # @return [String] human-readable model name
    attr_reader :name

    # @return [String] provider slug (e.g. "openai")
    attr_reader :provider

    # @return [String, nil] model family (e.g. "gpt", "claude")
    attr_reader :family

    # @return [Array<String>] capability strings
    attr_reader :capabilities

    # @return [Integer, nil] maximum context window in tokens
    attr_reader :context_window

    # @return [Integer, nil] maximum output tokens
    attr_reader :max_output_tokens

    # @return [Hash] input/output modalities
    attr_reader :modalities

    # @return [Hash] pricing information
    attr_reader :pricing

    # @return [Date, nil] knowledge cutoff date
    attr_reader :knowledge_cutoff

    # @return [String, nil] creation/publication date
    attr_reader :created_at

    # @return [Hash] additional metadata
    attr_reader :metadata

    def initialize(id:, name: nil, provider:, family: nil, capabilities: [],
                   context_window: nil, max_output_tokens: nil,
                   modalities: {}, pricing: {}, knowledge_cutoff: nil,
                   created_at: nil, metadata: {})
      @id = id
      @name = name || id
      @provider = provider.to_s
      @family = family
      @capabilities = Array(capabilities).map(&:to_s)
      @context_window = context_window
      @max_output_tokens = max_output_tokens
      @modalities = modalities
      @pricing = pricing
      @knowledge_cutoff = knowledge_cutoff
      @created_at = created_at
      @metadata = metadata
      freeze
    end

    # @return [Boolean] true if this is a chat model
    def chat? = type == "chat"

    # @return [Boolean] true if this is an embedding model
    def embedding? = type == "embedding" || modalities.dig(:output)&.include?("embeddings")

    # @return [Boolean] true if this model supports audio output
    def audio? = modalities.dig(:output)&.include?("audio")

    # @return [Boolean] true if this model supports image output
    def image? = modalities.dig(:output)&.include?("image")

    # Check if this model supports a given capability.
    # @param capability [String, Symbol] capability name
    # @return [Boolean]
    def supports?(capability)
      capabilities.include?(capability.to_s)
    end

    # @return [String] model type ("chat", "embedding", "audio", "image")
    def type
      @metadata[:type] || infer_type
    end

    # @return [Hash] serialized model info
    def to_h
      {
        id: @id,
        name: @name,
        provider: @provider,
        family: @family,
        capabilities: @capabilities,
        context_window: @context_window,
        max_output_tokens: @max_output_tokens,
        modalities: @modalities,
        pricing: @pricing,
        knowledge_cutoff: @knowledge_cutoff,
        created_at: @created_at,
        metadata: @metadata
      }.compact
    end

    # @return [String]
    def inspect
      "#<Ask::ModelInfo id=#{@id.inspect} provider=#{@provider.inspect}>"
    end

    private

    def infer_type
      return "chat" if supports?(:function_calling) || supports?(:structured_output)
      return "embedding" if @id.to_s.include?("embedding")
      return "audio" if audio?
      return "image" if image?
      "chat"
    end
  end

  # Parses raw models.dev API response JSON into {ModelInfo} objects.
  # Extracted into a module for independent unit testing.
  module ModelsDevParser
    # Maps models.dev provider keys to ask-rb provider slugs.
    PROVIDER_MAP = {
      "openai" => "openai",
      "anthropic" => "anthropic",
      "google" => "gemini",
      "google-vertex" => "vertexai",
      "amazon-bedrock" => "bedrock",
      "deepseek" => "deepseek",
      "mistral" => "mistral",
      "openrouter" => "openrouter",
      "perplexity" => "perplexity",
      "xai" => "xai",
      "github" => "github"
    }.freeze

    INPUT_MODALITIES = %w[text image audio pdf video file].freeze
    OUTPUT_MODALITIES = %w[text image audio video embeddings moderation].freeze

    module_function

    # Parse a raw models.dev API response into {ModelInfo} objects.
    # @param api_response [Hash] the parsed JSON from models.dev/api.json
    # @return [Array<Ask::ModelInfo>]
    def parse(api_response)
      api_response.flat_map do |provider_key, provider_data|
        provider_slug = PROVIDER_MAP[provider_key.to_s]
        next [] unless provider_slug

        models_data = provider_data.dig("models") || {}
        models_data.values.map do |model_data|
          build_model(model_data, provider_slug, provider_key.to_s)
        end
      end.compact
    end

    # Build a {ModelInfo} from a single model entry in the models.dev response.
    # @param model_data [Hash] the model data from the API
    # @param provider_slug [String] normalized provider slug
    # @param provider_key [String] original provider key from the API
    # @return [Ask::ModelInfo]
    def build_model(model_data, provider_slug, provider_key)
      modalities = normalize_modalities(model_data["modalities"])
      capabilities = extract_capabilities(model_data, modalities)
      pricing = build_pricing(model_data["cost"])
      created_date = [model_data["release_date"], model_data["last_updated"]]
                     .find { |v| v && !v.to_s.strip.empty? }

      ModelInfo.new(
        id: model_data["id"],
        name: model_data["name"] || model_data["id"],
        provider: provider_slug,
        family: model_data["family"],
        capabilities: capabilities,
        context_window: model_data.dig("limit", "context"),
        max_output_tokens: model_data.dig("limit", "output"),
        modalities: modalities,
        pricing: pricing,
        knowledge_cutoff: parse_date(model_data["knowledge"]),
        created_at: created_date,
        metadata: {
          source: "models.dev",
          provider_id: provider_key,
          open_weights: model_data["open_weights"],
          status: model_data["status"],
          reasoning_options: model_data["reasoning_options"]
        }.compact
      )
    end

    # @param modalities [Hash, nil] raw modalities hash
    # @return [Hash{Symbol => Array<String>}] normalized with known modality filters
    def normalize_modalities(modalities)
      return { input: [], output: [] } unless modalities

      {
        input: Array(modalities["input"]).compact & INPUT_MODALITIES,
        output: Array(modalities["output"]).compact & OUTPUT_MODALITIES
      }
    end

    # Extract capability strings from model data and modalities.
    # @param model_data [Hash] raw model data
    # @param modalities [Hash] normalized modalities
    # @return [Array<String>]
    def extract_capabilities(model_data, modalities)
      caps = []
      caps << "function_calling" if model_data["tool_call"]
      caps << "structured_output" if model_data["structured_output"]
      caps << "reasoning" if model_data["reasoning"] || model_data["reasoning_options"]
      caps << "vision" if modalities[:input].intersect?(%w[image video pdf])
      caps.uniq
    end

    # Build a pricing hash from raw cost data.
    # @param cost [Hash, nil] cost object from the API
    # @return [Hash]
    def build_pricing(cost)
      return {} unless cost

      text_standard = {
        input_per_million: cost["input"],
        output_per_million: cost["output"],
        cache_read_input_per_million: cost["cache_read"],
        cache_write_input_per_million: cost["cache_write"],
        reasoning_output_per_million: cost["reasoning"]
      }.compact

      audio_standard = {
        input_per_million: cost["input_audio"],
        output_per_million: cost["output_audio"]
      }.compact

      pricing = {}
      pricing[:text_tokens] = { standard: text_standard } if text_standard.any?
      pricing[:audio_tokens] = { standard: audio_standard } if audio_standard.any?
      pricing
    end

    # Parse a date from a string, returning nil on failure.
    # @param value [String, Date, nil]
    # @return [Date, nil]
    def parse_date(value)
      return nil if value.nil?
      return value if value.is_a?(Date)

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end

  # Catalog of available AI models. Provides model resolution by name/ID,
  # filtering by capability, and refresh from the models.dev API.
  #
  #   Ask::ModelCatalog.find("gpt-4o")
  #   Ask::ModelCatalog.chat_models
  #   Ask::ModelCatalog.refresh!
  #
  class ModelCatalog
    include Enumerable

    # @return [String] URL for the models.dev API
    MODELS_DEV_URL = "https://models.dev/api.json".freeze

    # Ordered provider preference for disambiguation.
    PROVIDER_PREFERENCE = %w[
      openai anthropic gemini vertexai bedrock
      openrouter deepseek mistral perplexity xai
      azure ollama gpustack github
    ].freeze

    # Methods delegated to the singleton instance.
    DELEGATES = %i[all each find chat_models embedding_models
                   audio_models image_models by_family by_provider
                   refresh!].freeze

    class << self
      DELEGATES.each do |method|
        define_method(method) do |*args, **kwargs, &block|
          instance.public_send(method, *args, **kwargs, &block)
        end
      end

      # @return [Ask::ModelCatalog] the process-wide singleton instance
      def instance
        @instance ||= new
      end

      # Reset the singleton instance (useful for testing).
      def reset_instance!
        @instance = nil
      end
    end

    # @param models [Array<Ask::ModelInfo>, nil] initial model list
    def initialize(models = nil)
      @models = models || []
    end

    # --- Querying ---

    # @return [Array<Ask::ModelInfo>] all models in the catalog
    def all
      @models
    end

    # @yield [Ask::ModelInfo]
    # @return [Enumerator]
    def each(&block)
      @models.each(&block)
    end

    # Find a model by ID, optionally scoped to a provider.
    # @param model_id [String] model identifier
    # @param provider [String, nil] provider slug
    # @return [Ask::ModelInfo]
    # @raise [ModelNotFound] if the model is not found
    def find(model_id, provider = nil)
      if provider
        find_with_provider(model_id, provider.to_s)
      else
        find_without_provider(model_id)
      end
    end

    # @return [Ask::ModelCatalog] new catalog containing only chat models
    def chat_models
      self.class.new(@models.select(&:chat?))
    end

    # @return [Ask::ModelCatalog] new catalog containing only embedding models
    def embedding_models
      self.class.new(@models.select(&:embedding?))
    end

    # @return [Ask::ModelCatalog] new catalog containing only audio models
    def audio_models
      self.class.new(@models.select(&:audio?))
    end

    # @return [Ask::ModelCatalog] new catalog containing only image models
    def image_models
      self.class.new(@models.select(&:image?))
    end

    # @param family [String] family name
    # @return [Ask::ModelCatalog] new catalog filtered by family
    def by_family(family)
      self.class.new(@models.select { |m| m.family.to_s == family.to_s })
    end

    # @param provider [String] provider slug
    # @return [Ask::ModelCatalog] new catalog filtered by provider
    def by_provider(provider)
      self.class.new(@models.select { |m| m.provider == provider.to_s })
    end

    # @return [Integer] number of models
    def length = @models.length
    alias size length

    # --- Refresh from models.dev ---

    # Fetch the latest model data from the models.dev API.
    # Falls back to current models if the API is unreachable.
    # @param timeout [Integer] HTTP timeout in seconds
    # @return [self]
    def refresh!(timeout: 10)
      @models = fetch_from_models_dev(timeout: timeout)
      self
    end

    # --- Registration ---

    # Register a single model, skipping duplicates.
    # @param model [Ask::ModelInfo]
    # @return [self]
    def register(model)
      @models << model unless @models.any? { |m| m.id == model.id && m.provider == model.provider }
      self
    end

    private

    def find_with_provider(model_id, provider)
      exact = @models.find { |m| m.id == model_id && m.provider == provider }
      return exact if exact

      @models.find { |m| m.id == model_id && m.provider == provider } ||
        raise(ModelNotFound, "Model #{model_id.inspect} not found for provider #{provider.inspect}. " \
                             "Try ModelCatalog.refresh! to update the catalog.")
    end

    def find_without_provider(model_id)
      matches = @models.select { |m| m.id == model_id }
      return preferred_match(matches) if matches.any?

      raise ModelNotFound, "Unknown model: #{model_id.inspect}. " \
                           "Try ModelCatalog.refresh! to update the catalog."
    end

    def preferred_match(candidates)
      return candidates.first if candidates.size == 1

      candidates.min_by do |model|
        PROVIDER_PREFERENCE.index(model.provider) || PROVIDER_PREFERENCE.length
      end
    end

    def fetch_from_models_dev(timeout: 10)
      uri = URI(MODELS_DEV_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = timeout
      http.read_timeout = timeout

      request = Net::HTTP::Get.new(uri)
      response = http.request(request)

      unless response.is_a?(Net::HTTPOK)
        warn "Failed to fetch models.dev: HTTP #{response.code}. Keeping existing models."
        return @models
      end

      providers_data = JSON.parse(response.body)
      ModelsDevParser.parse(providers_data)
    rescue StandardError => e
      warn "Failed to fetch models.dev: #{e.class}: #{e.message}. Keeping existing models."
      @models
    end
  end
end
