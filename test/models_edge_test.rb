# frozen_string_literal: true

require_relative "test_helper"

class ModelInfoEdgeTest < Minitest::Test
  def test_inspect
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai")
    assert_match(/ModelInfo.*gpt-4o.*openai/, info.inspect)
  end

  def test_audio_model
    info = Ask::ModelInfo.new(id: "whisper-1", provider: "openai",
                              modalities: { output: ["audio"] })
    assert info.audio?
  end

  def test_image_model
    info = Ask::ModelInfo.new(id: "dall-e-3", provider: "openai",
                              modalities: { output: ["image"] })
    assert info.image?
  end

  def test_type_inference_fallback_to_chat
    info = Ask::ModelInfo.new(id: "unknown-model", provider: "openai")
    assert info.chat?
    assert_equal "chat", info.type
  end

  def test_supports_capability
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai",
                              capabilities: ["function_calling", "vision"])
    assert info.supports?("function_calling")
    assert info.supports?(:vision)
    refute info.supports?("reasoning")
  end

  def test_name_defaults_to_id
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai")
    assert_equal "gpt-4o", info.name
  end

  def test_provider_normalized_to_string
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: :openai)
    assert_equal "openai", info.provider
    assert_instance_of String, info.provider
  end

  def test_capabilities_normalized_to_strings
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai",
                              capabilities: [:function_calling, :vision])
    assert info.supports?("function_calling")
    assert info.supports?("vision")
  end

  def test_knowledge_cutoff_date
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai",
                              knowledge_cutoff: Date.new(2024, 10, 1))
    assert_equal Date.new(2024, 10, 1), info.knowledge_cutoff
  end

  def test_created_at
    info = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai", created_at: "2024-05-01")
    assert_equal "2024-05-01", info.created_at
  end

  def test_to_h_with_all_fields
    info = Ask::ModelInfo.new(
      id: "gpt-4o", provider: "openai", name: "GPT-4o",
      family: "gpt", capabilities: ["function_calling"],
      context_window: 128_000, max_output_tokens: 4096,
      modalities: { input: ["text", "image"], output: ["text"] },
      pricing: { text_tokens: { standard: { input_per_million: 2.5 } } },
      metadata: { type: "chat" }
    )
    hash = info.to_h
    assert_equal "gpt-4o", hash[:id]
    assert_equal "GPT-4o", hash[:name]
    assert_equal "openai", hash[:provider]
    assert_equal 128_000, hash[:context_window]
  end
end

class ModelCatalogEdgeTest < Minitest::Test
  def setup
    @gpt4o = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai", family: "gpt")
    @claude = Ask::ModelInfo.new(id: "claude-sonnet-4", provider: "anthropic")
    @whisper = Ask::ModelInfo.new(id: "whisper-1", provider: "openai",
                                   modalities: { output: ["audio"] })
    @dalle = Ask::ModelInfo.new(id: "dall-e-3", provider: "openai",
                                 modalities: { output: ["image"] })
    @catalog = Ask::ModelCatalog.new([@gpt4o, @claude, @whisper, @dalle])
  end

  def test_audio_models
    audio = @catalog.audio_models
    assert_equal 1, audio.all.length
    assert_equal "whisper-1", audio.first.id
  end

  def test_image_models
    images = @catalog.image_models
    assert_equal 1, images.all.length
    assert_equal "dall-e-3", images.first.id
  end

  def test_by_family
    gpt35 = Ask::ModelInfo.new(id: "gpt-3.5-turbo", provider: "openai", family: "gpt")
    catalog = Ask::ModelCatalog.new([@gpt4o, gpt35])
    assert_equal 2, catalog.by_family("gpt").all.length
  end

  def test_by_family_no_match
    assert_equal 0, @catalog.by_family("nonexistent").length
  end

  def test_by_provider_no_match
    assert_equal 0, @catalog.by_provider("bedrock").length
  end

  def test_class_delegation_find
    Ask::ModelCatalog.reset_instance!
    catalog = Ask::ModelCatalog.instance
    assert_equal 0, catalog.length
  end

  def test_class_delegation_chat_models
    catalog = Ask::ModelCatalog.new([@gpt4o, @claude])
    Ask::ModelCatalog.stubs(:instance).returns(catalog)
    assert_equal 2, Ask::ModelCatalog.chat_models.all.length
  end

  def test_refresh_with_timeout
    catalog = Ask::ModelCatalog.new
    result = catalog.refresh!(timeout: 1)
    assert_same catalog, result
  end

  def test_to_h_on_model_info
    hash = @gpt4o.to_h
    assert_equal "gpt-4o", hash[:id]
  end

  def test_empty_catalog
    empty = Ask::ModelCatalog.new
    assert_equal 0, empty.length
    assert_empty empty.all
  end
end
