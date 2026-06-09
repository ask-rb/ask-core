# frozen_string_literal: true

require_relative "test_helper"

class ModelsDevParserTest < Minitest::Test
  def test_parse_openai_model
    api_data = {
      "openai" => {
        "models" => {
          "gpt-4o" => {
            "id" => "gpt-4o",
            "name" => "GPT-4o",
            "family" => "gpt",
            "modalities" => { "input" => ["text", "image"], "output" => ["text"] },
            "tool_call" => true,
            "structured_output" => true,
            "limit" => { "context" => 128_000, "output" => 4096 },
            "cost" => { "input" => 2.5, "output" => 10 },
            "release_date" => "2024-05-13"
          }
        }
      }
    }

    models = Ask::ModelsDevParser.parse(api_data)
    assert_equal 1, models.length
    model = models.first

    assert_equal "gpt-4o", model.id
    assert_equal "GPT-4o", model.name
    assert_equal "openai", model.provider
    assert_equal "gpt", model.family
    assert model.supports?("function_calling")
    assert model.supports?("structured_output")
    assert_equal 128_000, model.context_window
    assert_equal 4096, model.max_output_tokens
    assert_equal 2.5, model.pricing.dig(:text_tokens, :standard, :input_per_million)
    assert_equal 10, model.pricing.dig(:text_tokens, :standard, :output_per_million)
  end

  def test_parse_anthropic_model
    api_data = {
      "anthropic" => {
        "models" => {
          "claude-sonnet-4-20250514" => {
            "id" => "claude-sonnet-4-20250514",
            "family" => "claude",
            "modalities" => { "input" => ["text", "image", "pdf"], "output" => ["text"] },
            "tool_call" => true,
            "structured_output" => true,
            "reasoning" => true,
            "limit" => { "context" => 200_000 },
            "cost" => { "input" => 3, "output" => 15, "cache_read" => 0.30 }
          }
        }
      }
    }

    models = Ask::ModelsDevParser.parse(api_data)
    assert_equal 1, models.length
    model = models.first

    assert_equal "claude-sonnet-4-20250514", model.id
    assert_equal "anthropic", model.provider
    assert model.supports?("reasoning")
    assert model.supports?("function_calling")
    assert model.supports?("vision") # Due to image/pdf input modalities
    assert_equal 200_000, model.context_window
    assert_equal 0.30, model.pricing.dig(:text_tokens, :standard, :cache_read_input_per_million)
  end

  def test_skip_unknown_provider
    api_data = {
      "unknown-vendor" => {
        "models" => {
          "foo" => { "id" => "foo", "modalities" => {} }
        }
      }
    }

    models = Ask::ModelsDevParser.parse(api_data)
    assert_empty models
  end

  def test_empty_modalities
    model = Ask::ModelsDevParser.build_model(
      { "id" => "test-model", "modalities" => nil },
      "test", "test"
    )
    assert_equal "test-model", model.id
    assert_equal({ input: [], output: [] }, model.modalities)
  end

  def test_pricing_audio
    cost = { "input_audio" => 100, "output_audio" => 200 }
    pricing = Ask::ModelsDevParser.build_pricing(cost)
    assert_equal 100, pricing.dig(:audio_tokens, :standard, :input_per_million)
    assert_equal 200, pricing.dig(:audio_tokens, :standard, :output_per_million)
  end

  def test_pricing_empty
    assert_equal({}, Ask::ModelsDevParser.build_pricing(nil))
  end

  def test_parse_date_nil
    assert_nil Ask::ModelsDevParser.parse_date(nil)
  end

  def test_parse_date_from_string
    date = Ask::ModelsDevParser.parse_date("2024-05-13")
    assert_equal Date.new(2024, 5, 13), date
  end

  def test_parse_date_already_date
    d = Date.new(2024, 1, 1)
    assert_same d, Ask::ModelsDevParser.parse_date(d)
  end

  def test_parse_date_invalid_string
    assert_nil Ask::ModelsDevParser.parse_date("not-a-date")
  end

  def test_normalize_modalities_filters_unknown
    raw = { "input" => ["text", "hologram"], "output" => ["text", "telepathy"] }
    result = Ask::ModelsDevParser.normalize_modalities(raw)
    assert_equal %w[text], result[:input]
    assert_equal %w[text], result[:output]
  end

  def test_extract_capabilities_vision_from_images
    model_data = {}
    modalities = { input: ["image", "video", "pdf"] }
    caps = Ask::ModelsDevParser.extract_capabilities(model_data, modalities)
    assert_includes caps, "vision"
  end

  def test_extract_capabilities_reasoning_options
    model_data = { "reasoning_options" => true }
    modalities = { input: ["text"], output: ["text"] }
    caps = Ask::ModelsDevParser.extract_capabilities(model_data, modalities)
    assert_includes caps, "reasoning"
  end

  def test_build_model_without_optional_fields
    model = Ask::ModelsDevParser.build_model(
      { "id" => "minimal", "modalities" => {} },
      "test", "test"
    )
    assert_equal "minimal", model.id
    assert_equal "minimal", model.name
    assert_equal "test", model.provider
  end

  def test_build_model_with_release_date
    model = Ask::ModelsDevParser.build_model(
      {
        "id" => "dated-model",
        "modalities" => {},
        "release_date" => "2025-01-15",
        "last_updated" => "2025-06-01"
      },
      "openai", "openai"
    )
    assert_equal "2025-01-15", model.created_at
  end

  def test_build_model_without_release_date_uses_last_updated
    model = Ask::ModelsDevParser.build_model(
      {
        "id" => "updated-model",
        "modalities" => {},
        "last_updated" => "2025-06-01"
      },
      "openai", "openai"
    )
    assert_equal "2025-06-01", model.created_at
  end
end
