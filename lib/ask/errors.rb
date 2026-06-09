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

  # Raised when the API rate limit is hit.
  class RateLimitError < Error; end

  # Raised when authentication fails.
  class Unauthorized < Error; end

  # Raised when the server returns a 5xx error.
  class ServerError < Error; end

  # Raised when the service is unavailable.
  class ServiceUnavailable < Error; end

  # Raised when a provider's API returns an unexpected response.
  # @!attribute [r] status_code
  #   @return [Integer, nil] the HTTP status code
  # @!attribute [r] response_body
  #   @return [String, nil] the raw response body
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
