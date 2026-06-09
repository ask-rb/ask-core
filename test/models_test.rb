# frozen_string_literal: true

require_relative "test_helper"

class ModelInfoTest < Minitest::Test
  def test_basic_model_info
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai")
    assert_equal "gpt-4o", info.id
    assert_equal "openai", info.provider
    assert_equal "gpt-4o", info.name
  end

  def test_name_fallback
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai", name: "GPT-4o Optimized")
    assert_equal "GPT-4o Optimized", info.name
  end

  def test_capabilities
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai",
                              capabilities: %w[function_calling vision])
    assert info.supports?("function_calling")
    assert info.supports?(:vision)
    refute info.supports?("reasoning")
  end

  def test_chat_model
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai",
                              capabilities: ["function_calling"])
    assert info.chat?
    refute info.embedding?
  end

  def test_embedding_model
    info = Ask::ModelInfo.new(id: "text-embedding-3-small", provider: "openai")
    assert info.embedding?
  end

  def test_to_h
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai", context_window: 128_000)
    hash = info.to_h
    assert_equal "gpt-4o", hash[:id]
    assert_equal 128_000, hash[:context_window]
  end

  def test_to_h_compacts_nils
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai")
    hash = info.to_h
    assert_nil hash[:context_window]
  end

  def test_immutable
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai")
    assert info.frozen?
  end

  def test_pricing
    pricing = { text_tokens: { standard: { input_per_million: 2.5, output_per_million: 10 } } }
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai", pricing: pricing)
    assert_equal 2.5, info.pricing.dig(:text_tokens, :standard, :input_per_million)
  end
end

class ModelCatalogTest < Minitest::Test
  def setup
    @gpt4o = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai",
                                 capabilities: %w[function_calling vision],
                                 context_window: 128_000)
    @claude = Ask::ModelInfo.new(id: "claude-sonnet-4", provider: "anthropic",
                                  capabilities: %w[function_calling reasoning],
                                  context_window: 200_000)
    @embed = Ask::ModelInfo.new(id: "text-embedding-3-small", provider: "openai")

    @catalog = Ask::ModelCatalog.new([@gpt4o, @claude, @embed])
  end

  def test_all
    assert_equal 3, @catalog.all.length
  end

  def test_find_by_id
    model = @catalog.find("gpt-4o")
    assert_equal "gpt-4o", model.id
    assert_equal "openai", model.provider
  end

  def test_find_with_provider
    model = @catalog.find("gpt-4o", "openai")
    assert_equal "gpt-4o", model.id
  end

  def test_find_wrong_provider
    assert_raises(Ask::ModelNotFound) { @catalog.find("gpt-4o", "anthropic") }
  end

  def test_find_unknown
    assert_raises(Ask::ModelNotFound) { @catalog.find("nonexistent") }
  end

  def test_chat_models
    chats = @catalog.chat_models
    assert_equal 2, chats.all.length
  end

  def test_embedding_models
    embeddings = @catalog.embedding_models
    assert_equal 1, embeddings.all.length
  end

  def test_by_provider
    openai_models = @catalog.by_provider("openai")
    assert_equal 2, openai_models.all.length
  end

  def test_by_family
    @gpt4o_with_family = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai", family: "gpt")
    catalog = Ask::ModelCatalog.new([@gpt4o_with_family])
    assert_equal 1, catalog.by_family("gpt").all.length
  end

  def test_each
    ids = []
    @catalog.each { |m| ids << m.id }
    assert_equal %w[gpt-4o claude-sonnet-4 text-embedding-3-small], ids
  end

  def test_length
    assert_equal 3, @catalog.length
    assert_equal 3, @catalog.size
  end

  def test_register_model
    new_model = Ask::ModelInfo.new(id: "new-model", provider: "openai")
    @catalog.register(new_model)
    assert_equal 4, @catalog.length
  end

  def test_register_duplicate
    dup = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai", context_window: 999)
    @catalog.register(dup)
    assert_equal 3, @catalog.length # not added
  end

  def test_instance_delegation
    Ask::ModelCatalog.reset_instance!
    refute_nil Ask::ModelCatalog.instance
    assert_instance_of Ask::ModelCatalog, Ask::ModelCatalog.instance
  end

  def test_preferred_match_prefers_ordered_providers
    gpt_openai = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai")
    gpt_azure = Ask::ModelInfo.new(id: "gpt-4o", provider: "azure")
    catalog = Ask::ModelCatalog.new([gpt_openai, gpt_azure])

    found = catalog.find("gpt-4o")
    assert_equal "openai", found.provider
  end
end
