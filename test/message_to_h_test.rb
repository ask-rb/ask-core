# frozen_string_literal: true

require "ostruct"
require_relative "test_helper"

class MessageToHTest < Minitest::Test
  def setup
    @weather_tool = OpenStruct.new(
      id: "call_1",
      name: "get_weather",
      arguments: '{"location":"Berlin"}'
    )
  end

  def test_to_h_without_tool_calls
    msg = Ask::Message.new(role: :user, content: "Hello")
    h = msg.to_h
    assert_equal :user, h[:role]
    assert_equal "Hello", h[:content]
    refute h.key?(:tool_calls)
  end

  def test_to_h_with_tool_calls_os
    msg = Ask::Message.new(
      role: :assistant,
      content: nil,
      tool_calls: { "call_1" => @weather_tool }
    )
    h = msg.to_h
    assert h.key?(:tool_calls)
    assert_kind_of Array, h[:tool_calls]
    assert_equal 1, h[:tool_calls].size

    tc = h[:tool_calls].first
    assert_equal "call_1", tc[:id]
    assert_equal "function", tc[:type]
    assert_equal "get_weather", tc.dig(:function, :name)
    assert_equal '{"location":"Berlin"}', tc.dig(:function, :arguments)
  end

  def test_to_h_with_tool_calls_hash
    msg = Ask::Message.new(
      role: :assistant,
      content: nil,
      tool_calls: { "call_1" => { id: "call_1", name: "get_weather", arguments: "{}" } }
    )
    h = msg.to_h
    assert_kind_of Array, h[:tool_calls]
    tc = h[:tool_calls].first
    assert_equal "call_1", tc[:id]
    assert_equal "get_weather", tc.dig(:function, :name)
  end

  def test_to_h_with_no_tool_calls_does_not_include_key
    msg = Ask::Message.new(role: :assistant, content: "Just text")
    h = msg.to_h
    refute h.key?(:tool_calls)
  end

  def test_to_h_preserves_array_tool_calls
    tool_calls = [
      { id: "call_1", type: "function", function: { name: "get_weather", arguments: "{}" } }
    ]
    msg = Ask::Message.new(role: :assistant, content: nil, tool_calls: tool_calls)
    h = msg.to_h
    assert_kind_of Array, h[:tool_calls]
    assert_equal tool_calls, h[:tool_calls]
  end

  def test_to_h_serializes_to_json
    msg = Ask::Message.new(
      role: :assistant,
      content: nil,
      tool_calls: { "call_1" => @weather_tool }
    )
    json = JSON.generate(msg.to_h)
    parsed = JSON.parse(json)
    assert_kind_of Array, parsed["tool_calls"]
    assert_equal "call_1", parsed["tool_calls"][0]["id"]
    assert_equal "get_weather", parsed["tool_calls"][0]["function"]["name"]
  end

  def test_to_h_includes_tool_call_id
    msg = Ask::Message.new(role: :tool, content: "Result", tool_call_id: "call_1")
    h = msg.to_h
    assert_equal "call_1", h[:tool_call_id]
  end
end
