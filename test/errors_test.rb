# frozen_string_literal: true

require_relative "test_helper"

class ErrorsTest < Minitest::Test
  def test_error_base_class
    assert Ask::Error < StandardError
  end

  def test_configuration_error
    assert Ask::ConfigurationError < Ask::Error
  end

  def test_unknown_provider
    assert Ask::UnknownProvider < Ask::Error
  end

  def test_model_not_found
    assert Ask::ModelNotFound < Ask::Error
  end

  def test_invalid_role
    assert Ask::InvalidRole < Ask::Error
  end

  def test_provider_error_with_status
    error = Ask::ProviderError.new("Bad gateway", status_code: 502, response_body: "upstream down")
    assert_equal 502, error.status_code
    assert_equal "upstream down", error.response_body
    assert_equal "Bad gateway", error.message
  end

  def test_provider_error_without_optional_args
    error = Ask::ProviderError.new("Something went wrong")
    assert_nil error.status_code
    assert_nil error.response_body
  end

  def test_context_length_exceeded
    assert Ask::ContextLengthExceeded < Ask::Error
  end

  def test_rate_limit_error
    assert Ask::RateLimitError < Ask::Error
  end

  def test_rate_limit_error_with_category
    error = Ask::RateLimitError.new("Rate limited", category: Ask::RateLimitCategory::VENDOR, rate_limit_type: Ask::RateLimitType::TOKENS, retry_after: 30)
    assert_equal Ask::RateLimitCategory::VENDOR, error.category
    assert_equal Ask::RateLimitType::TOKENS, error.rate_limit_type
    assert_equal 30, error.retry_after
  end

  def test_rate_limit_error_defaults
    error = Ask::RateLimitError.new("too fast")
    assert_nil error.category
    assert_nil error.rate_limit_type
    assert_nil error.retry_after
  end

  def test_rate_limit_category_constants
    assert_equal :vendor, Ask::RateLimitCategory::VENDOR
    assert_equal :local, Ask::RateLimitCategory::LOCAL
  end

  def test_rate_limit_type_constants
    assert_equal :requests, Ask::RateLimitType::REQUESTS
    assert_equal :tokens, Ask::RateLimitType::TOKENS
    assert_equal :concurrent, Ask::RateLimitType::CONCURRENT
    assert_equal :budget, Ask::RateLimitType::BUDGET
  end

  def test_unauthorized
    assert Ask::Unauthorized < Ask::Error
  end

  def test_invalid_tool_definition
    assert Ask::InvalidToolDefinition < Ask::Error
  end

  def test_conversation_error
    assert Ask::ConversationError < Ask::Error
  end

  def test_stream_error
    assert Ask::StreamError < Ask::Error
  end

  def test_unsupported_feature
    assert Ask::UnsupportedFeature < Ask::Error
  end

  def test_missing_credential
    assert Ask::MissingCredential < Ask::Error
  end

  def test_invalid_credential
    assert Ask::InvalidCredential < Ask::Error
  end

  def test_server_error
    assert Ask::ServerError < Ask::Error
  end

  def test_service_unavailable
    assert Ask::ServiceUnavailable < Ask::Error
  end
end
