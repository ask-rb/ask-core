# frozen_string_literal: true

require_relative "test_helper"

class ToolDefTest < Minitest::Test
  def test_basic_tool_def
    tool = Ask::ToolDef.new(
      name: "get_weather",
      description: "Get the current weather",
      parameters: {
        type: "object",
        properties: {
          location: { type: "string", description: "City name" }
        },
        required: ["location"]
      }
    )
    assert_equal "get_weather", tool.name
    assert_equal "Get the current weather", tool.description
    assert_equal "object", tool.parameters[:type]
  end

  def test_minimal_tool_def
    tool = Ask::ToolDef.new(name: "ping")
    assert_equal "ping", tool.name
    assert_equal "", tool.description
    assert_equal({ type: "object", properties: {}, required: [] }, tool.to_provider_format)
  end

  def test_tool_def_immutable
    tool = Ask::ToolDef.new(name: "test", provider_params: { key: "value" })
    assert tool.frozen?
    assert tool.provider_params.frozen?
  end

  def test_invalid_name_raises
    assert_raises(Ask::InvalidToolDefinition) { Ask::ToolDef.new(name: "") }
    assert_raises(Ask::InvalidToolDefinition) { Ask::ToolDef.new(name: nil) }
    assert_raises(Ask::InvalidToolDefinition) { Ask::ToolDef.new(name: "has space") }
    assert_raises(Ask::InvalidToolDefinition) { Ask::ToolDef.new(name: "special!chars") }
  end

  def test_valid_names_accepted
    assert Ask::ToolDef.new(name: "simple")
    assert Ask::ToolDef.new(name: "with_underscore")
    assert Ask::ToolDef.new(name: "with-hyphen")
    assert Ask::ToolDef.new(name: "camelCase")
    assert Ask::ToolDef.new(name: "UPPERCASE")
    assert Ask::ToolDef.new(name: "with_numbers_123")
  end

  def test_equality_by_name
    a = Ask::ToolDef.new(name: "foo", description: "First")
    b = Ask::ToolDef.new(name: "foo", description: "Second")
    c = Ask::ToolDef.new(name: "bar")

    assert_equal a, b
    refute_equal a, c
    assert_equal [a, c].uniq, [a, c]
  end

  def test_to_provider_format_with_block
    tool = Ask::ToolDef.new(name: "test", parameters: { type: "object", properties: {} })
    result = tool.to_provider_format { |t| { custom: t.name } }
    assert_equal({ custom: "test" }, result)
  end

  def test_to_provider_format_without_block
    params = { type: "object", properties: { x: { type: "string" } }, required: ["x"] }
    tool = Ask::ToolDef.new(name: "test", parameters: params)
    assert_equal params, tool.to_provider_format
  end

  def test_to_h
    tool = Ask::ToolDef.new(name: "test", description: "desc",
                            parameters: { type: "object", properties: {} },
                            provider_params: { option: true })
    hash = tool.to_h
    assert_equal "test", hash[:name]
    assert_equal "desc", hash[:description]
    assert_equal true, hash[:provider_params][:option]
  end

  def test_from_tool_with_tool_like_object
    fake_tool = Object.new
    fake_tool.define_singleton_method(:name) { "my_tool" }
    fake_tool.define_singleton_method(:description) { "Does something" }
    fake_tool.define_singleton_method(:params_schema) do
      { type: "object", properties: {}, required: [] }
    end
    fake_tool.define_singleton_method(:provider_params) { { extra: true } }

    tool = Ask::ToolDef.from_tool(fake_tool)
    assert_equal "my_tool", tool.name
    assert_equal "Does something", tool.description
    assert_equal true, tool.provider_params[:extra]
  end

  def test_inspect
    tool = Ask::ToolDef.new(name: "my_tool")
    assert_match(/ToolDef.*my_tool/, tool.inspect)
  end
end
