# frozen_string_literal: true

module Ask
  # Abstract base class for all LLM providers. Defines the interface that
  # provider gems (ask-openai, ask-anthropic, etc.) must implement.
  #
  # Provider gems subclass this and implement the abstract methods:
  # - {#chat} — send a chat completion request
  # - {#embed} — generate embeddings
  # - {#list_models} — list available models
  # - {#api_base} — provider API base URL
  #
  # Providers register themselves via {.register} so that
  # {.resolve} returns the correct class by name.
  #
  # @example Defining a custom provider
  #   class MyProvider < Ask::Provider
  #     def api_base = "https://api.example.com/v1"
  #     def headers = { "Authorization" => "Bearer #{@config.api_key}" }
  #     def chat(messages, model:, **opts, &block) = # ...
  #     def embed(text, model:) = # ...
  #     def list_models = # ...
  #   end
  #   Ask::Provider.register(:my, MyProvider)
  #
  class Provider
    # Global mutex protecting the provider registry.
    REGISTRY_MUTEX = Mutex.new
    private_constant :REGISTRY_MUTEX

    # @return [Object] the configuration object passed to the constructor
    attr_reader :config

    # @param config [Object] provider configuration (must respond to configuration_requirements)
    def initialize(config = {})
      @config = config
      ensure_configured!
    end

    # --- Abstract interface (provider gems implement these) ---

    # Send a chat completion request.
    # @param messages [Array<Ask::Message>] conversation messages
    # @param model [String] model ID to use
    # @param tools [Array<Ask::ToolDef>, nil] tool definitions
    # @param temperature [Float, nil] sampling temperature
    # @param stream [Boolean, nil] if true, yield {Ask::Chunk}s to the block
    # @param schema [Hash, nil] JSON schema for structured output
    # @yield [Ask::Chunk] yields chunks when streaming
    # @return [Ask::Message] the assistant's response
    def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
      raise NotImplementedError, "#{self.class} must implement #chat"
    end

    # Generate embeddings for the given text.
    # @param text [String] input text
    # @param model [String] embedding model ID
    # @return [Array<Float>] embedding vector
    def embed(text, model:)
      raise NotImplementedError, "#{self.class} must implement #embed"
    end

    # List available models from this provider.
    # @return [Array<Ask::ModelInfo>] available models
    def list_models
      raise NotImplementedError, "#{self.class} must implement #list_models"
    end

    # @abstract The base URL for this provider's API.
    # @return [String]
    def api_base
      raise NotImplementedError, "#{self.class} must implement #api_base"
    end

    # --- Optional overrides ---

    # Additional HTTP headers for API requests.
    # @return [Hash<String, String>]
    def headers
      {}
    end

    # Parse an error response body into a human-readable message.
    # @param response [Object] the error response
    # @return [String, nil]
    def parse_error(response)
      nil
    end

    # @return [Boolean] true if the provider runs locally (e.g., Ollama)
    def local? = self.class.local?

    # @return [Boolean] true if the provider requires a remote API
    def remote? = !local?

    # @return [Boolean] true if all models can be assumed to exist
    def assume_models_exist? = self.class.assume_models_exist?

    # --- Slug / name / capabilities ---

    # @return [String] lowercased provider slug
    def slug
      self.class.slug
    end

    # @return [String] provider name (demodulized class name)
    def name
      self.class.name
    end

    # @return [Hash, nil] provider capabilities metadata
    def capabilities
      self.class.capabilities
    end

    # --- Registry (class-level) ---

    class << self
      # Register a provider class so it can be resolved by name.
      # Thread-safe via {REGISTRY_MUTEX}.
      # @param name [Symbol] short name for the provider
      # @param provider_class [Class<Ask::Provider>] the provider class
      def register(name, provider_class)
        REGISTRY_MUTEX.synchronize do
          registry[name.to_sym] = provider_class
        end
      end

      # Resolve a registered provider by name.
      # Thread-safe via {REGISTRY_MUTEX}.
      # @param name [Symbol, String] provider name
      # @return [Class<Ask::Provider>]
      # @raise [UnknownProvider] if not registered
      def resolve(name)
        REGISTRY_MUTEX.synchronize do
          registry[name.to_sym] || raise(UnknownProvider,
                                          "Unknown provider: #{name.inspect}. " \
                                          "Available: #{registry.keys.join(', ')}")
        end
      end

      # Return a shallow copy of all registered providers.
      # Thread-safe via {REGISTRY_MUTEX}.
      # @return [Hash{Symbol => Class<Ask::Provider>}]
      def providers
        REGISTRY_MUTEX.synchronize do
          registry.dup
        end
      end

      # Clear all registered providers (used in testing).
      def clear_providers!
        REGISTRY_MUTEX.synchronize do
          @registry = {}
        end
      end

      # @return [String] lowercased, underscored slug from the class name
      def slug
        name.split("::").last.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
      end

      # @return [String] class name without module prefix
      def name
        to_s.split("::").last
      end

      # @return [Hash, nil] capabilities
      def capabilities
        nil
      end

      # @return [Array<Symbol>] config keys this provider supports
      def configuration_options
        []
      end

      # @return [Array<Symbol>] config keys this provider requires
      def configuration_requirements
        []
      end

      # Check if this provider is fully configured.
      # @param config [Object] configuration object
      # @return [Boolean]
      def configured?(config)
        configuration_requirements.all? { |req| config.respond_to?(req) && config.public_send(req) }
      end

      # @return [Boolean] true if this provider runs locally
      def local?
        false
      end

      # @return [Boolean] true if this provider requires a remote API
      def remote?
        !local?
      end

      # @return [Boolean] whether all models can be assumed to exist
      def assume_models_exist?
        false
      end

      private

      # The internal registry hash (access must be synchronized via REGISTRY_MUTEX).
      def registry
        @registry ||= {}
      end
    end

    private

    def normalize_config(config)
      config
    end

    def ensure_configured!
      missing = self.class.configuration_requirements.reject do |req|
        @config.respond_to?(req) && @config.public_send(req)
      end
      return if missing.empty?

      raise ConfigurationError,
            "Missing configuration for #{self.class.name}: #{missing.join(', ')}. " \
            "Set these keys on your provider config before using this provider."
    end
  end
end
