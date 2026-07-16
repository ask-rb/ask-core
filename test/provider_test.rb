# frozen_string_literal: true

require_relative "test_helper"

class ProviderTest < Minitest::Test
  include TestHelpers

  def setup
    @provider_class = nil
    Ask::Provider.clear_providers!
  end

  def teardown
    Ask::Provider.clear_providers!
  end

  def test_register_and_resolve
    klass = stub_provider_class
    Ask::Provider.register(:test, klass)
    assert_equal klass, Ask::Provider.resolve(:test)
  end

  def test_resolve_unknown
    assert_raises(Ask::UnknownProvider) { Ask::Provider.resolve(:nonexistent) }
  end

  def test_slug
    klass = stub_provider_class(name: "OpenAI", slug: "openai")
    assert_equal "openai", klass.slug
  end

  def test_providers_registry
    klass = stub_provider_class
    Ask::Provider.register(:a, klass)
    Ask::Provider.register(:b, klass)
    assert_equal 2, Ask::Provider.providers.size
  end

  def test_configuration_requirements
    klass = stub_provider_class
    klass.define_singleton_method(:configuration_requirements) { [:api_key] }
    klass.define_singleton_method(:configuration_options) { [:api_key, :api_base] }

    assert_equal [:api_key], klass.configuration_requirements
    assert_equal [:api_key, :api_base], klass.configuration_options
  end

  def test_configured?
    klass = stub_provider_class
    klass.define_singleton_method(:configuration_requirements) { [:api_key] }

    config = stub_config(api_key: "abc")
    assert klass.configured?(config)

    config = stub_config(api_key: nil)
    refute klass.configured?(config)
  end

  def test_subclass_implements_chat
    klass = stub_provider_class
    provider = klass.new(stub_config(api_key: "test"))

    msg = provider.chat(
      [Ask::Message.new(role: :user, content: "Hi")],
      model: "test-model"
    )
    assert_instance_of Ask::Message, msg
    assert_equal "Echo: Hi", msg.content
  end

  def test_subclass_implements_embed
    klass = stub_provider_class
    provider = klass.new(stub_config(api_key: "test"))

    result = provider.embed("Hello", model: "text-embedding-ada-002")
    assert_equal [0.1, 0.2, 0.3], result
  end

  def test_subclass_implements_list_models
    klass = stub_provider_class
    provider = klass.new(stub_config(api_key: "test"))

    models = provider.list_models
    assert_equal 1, models.length
    assert_instance_of Ask::ModelInfo, models.first
  end

  def test_local_and_remote
    klass = stub_provider_class
    refute klass.local?
    assert klass.remote?
  end

  def test_local_provider
    klass = stub_provider_class
    klass.define_singleton_method(:local?) { true }
    klass.define_singleton_method(:remote?) { false }

    assert klass.local?
    refute klass.remote?
  end

  def test_configuration_error_on_missing
    klass = stub_provider_class
    klass.define_singleton_method(:configuration_requirements) { [:api_key] }

    config = stub_config(api_key: nil)
    error = assert_raises(Ask::ConfigurationError) { klass.new(config) }
    assert_match(/api_key/, error.message)
  end

  def test_abstract_methods_raise
    provider = AbstractStubProvider.new(stub_config(api_key: "test"))

    assert_raises(NotImplementedError) { provider.api_base }
    assert_raises(NotImplementedError) { provider.chat([], model: "m") }
    assert_raises(NotImplementedError) { provider.embed("t", model: "m") }
    assert_raises(NotImplementedError) { provider.list_models }
  end

  def test_headers_default
    provider = AbstractStubProvider.new(stub_config(api_key: "test"))
    assert_equal({}, provider.headers)
  end

  def test_parse_error_default
    provider = AbstractStubProvider.new(stub_config(api_key: "test"))
    assert_nil provider.parse_error("{}")
  end

end

# A completely abstract provider with no interface methods implemented
class AbstractStubProvider < Ask::Provider
  def initialize(config)
    super(config)
  end

  def configuration_requirements
    []
  end
end
