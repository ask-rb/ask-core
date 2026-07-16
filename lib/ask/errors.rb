# frozen_string_literal: true

module Ask
  # Base error class for all ask-rb errors.
  class Error < StandardError; end

  # Raised when a provider is not configured properly.
  class ConfigurationError < Error; end

  # Raised when a required credential is missing.
  class MissingCredential < Error; end

  # Raised when a credential is invalid or expired.
  class InvalidCredential < Error; end

  # Raised when an unknown provider is requested.
  class UnknownProvider < Error; end

  # Raised when a model is not found in the catalog.
  class ModelNotFound < Error; end

  # Raised when a message has an invalid role.
  class InvalidRole < Error; end

  # Raised when a tool definition is invalid.
  class InvalidToolDefinition < Error; end

  # Raised when the context window is exceeded.
  class ContextLengthExceeded < Error; end

  # Raised when authentication fails.
  class Unauthorized < Error; end

  # Raised when the server returns a 5xx error.
  class ServerError < Error; end

  # Raised when the service is unavailable.
  class ServiceUnavailable < Error; end

  # Categories for {RateLimitError} — tells you who rate-limited the request.
  module RateLimitCategory
    VENDOR = :vendor  # upstream LLM provider (OpenAI, Anthropic, etc.)
    LOCAL  = :local   # ask-rb's own limiter (ask-auth thresholds)
  end

  # Rate limit dimension that was exceeded — orthogonal to {RateLimitCategory}.
  module RateLimitType
    REQUESTS   = :requests    # requests-per-minute ceiling
    TOKENS     = :tokens      # tokens-per-minute ceiling
    CONCURRENT = :concurrent  # max parallel requests
    BUDGET     = :budget      # spend budget cap
  end

  # Raised when the API rate limit is hit.
  # Carries optional category, type, and retry_after for intelligent handling.
  class RateLimitError < Error
    # @return [Symbol, nil] who rate-limited (:vendor, :local)
    attr_reader :category

    # @return [Symbol, nil] which limit was hit (:requests, :tokens, :concurrent, :budget)
    attr_reader :rate_limit_type

    # @return [Integer, Float, nil] suggested seconds to wait before retrying
    attr_reader :retry_after

    def initialize(message, category: nil, rate_limit_type: nil, retry_after: nil)
      @category = category
      @rate_limit_type = rate_limit_type
      @retry_after = retry_after
      super(message)
    end
  end

  # Raised when a provider's API returns an unexpected response.
  class ProviderError < Error
    attr_reader :status_code, :response_body

    def initialize(message = nil, status_code: nil, response_body: nil)
      @status_code = status_code
      @response_body = response_body
      super(message)
    end
  end

  # Raised when a conversation operation receives an invalid state.
  class ConversationError < Error; end

  # Raised when streaming encounters an error.
  class StreamError < Error; end

  # Raised when a feature is not supported by the selected provider/model.
  class CapabilityNotSupported < Error; end

  class UnsupportedFeature < Error; end
end
