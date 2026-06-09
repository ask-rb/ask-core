# frozen_string_literal: true

require_relative "test_helper"

class ProviderEdgeTest < Minitest::Test
  include TestHelpers

  def setup
    Ask::Provider.clear_providers!
  end

  def teardown
    Ask::Provider.clear_providers!
  end

  def test_slug_uses_stub_slug
    klass = stub_provider_class(name: "Anthropic")
    assert_equal "test_provider", klass.slug
  end

  def test_name_class_method
    klass = stub_provider_class(name: "OpenAI")
    assert_equal "OpenAI", klass.name
  end

  def test_capabilities_class_method_returns_nil_by_default
    klass = stub_provider_class
    assert_nil klass.capabilities
  end

  def test_configuration_options_returns_empty_by_default
    klass = stub_provider_class
    assert_equal [], klass.configuration_options
  end

  def test_slug_instance_method
    klass = stub_provider_class(name: "TestProvider", slug: "test_provider")
    assert_equal "test_provider", klass.new(stub_config(api_key: "test")).slug
  end

  def test_name_instance_method
    klass = stub_provider_class(name: "TestProvider")
    assert_equal "TestProvider", klass.new(stub_config(api_key: "test")).name
  end

  def test_capabilities_instance_method
    klass = stub_provider_class
    klass.define_singleton_method(:capabilities) { { chat: true } }
    assert_equal({ chat: true }, klass.new(stub_config(api_key: "test")).capabilities)
  end

  def test_slug_demodulizes_namespace
    klass = Class.new(Ask::Provider) do
      def self.name = "Ask::Providers::OpenAI"
      def api_base = "https://test.com"
    end
    klass.new(stub_config)
    assert_equal "open_ai", klass.slug
  end

  def test_configured_with_all_requirements
    klass = stub_provider_class
    klass.define_singleton_method(:configuration_requirements) { [:key, :secret] }
    assert klass.configured?(stub_config(key: "abc", secret: "xyz"))
  end

  def test_configured_with_missing_requirement
    klass = stub_provider_class
    klass.define_singleton_method(:configuration_requirements) { [:key, :secret] }
    refute klass.configured?(stub_config(key: "abc", secret: nil))
  end

  def test_remote_is_default
    klass = stub_provider_class
    assert klass.remote?
    refute klass.local?
  end

  def test_local_provider_defaults
    klass = stub_provider_class
    klass.define_singleton_method(:local?) { true }
    klass.define_singleton_method(:remote?) { false }
    prov = klass.new(stub_config(api_key: "test"))
    assert prov.local?
    refute prov.remote?
  end

  def test_assume_models_exist_default
    klass = stub_provider_class
    refute klass.assume_models_exist?
  end

  def test_instance_assume_models_exist
    prov = stub_provider_class.new(stub_config(api_key: "test"))
    refute prov.assume_models_exist?
  end

  def test_parse_error_default_returns_nil
    prov = stub_provider_class.new(stub_config(api_key: "test"))
    assert_nil prov.parse_error("error body")
  end

  def test_resolve_unknown_has_helpful_message
    Ask::Provider.register(:test, stub_provider_class)
    error = assert_raises(Ask::UnknownProvider) { Ask::Provider.resolve(:nope) }
    assert_match(/test/, error.message)
  end
end
