# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../ask-core/lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../ask-llm-providers/lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../ask-auth/lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../ask-tools/lib", __dir__)

require "ostruct"
require "ask-llm-providers"
require "ask/agent"
require "minitest/autorun"
require "json"

# Integration test: simulate the EXACT flow the proxy uses
class ProxyIntegrationTest < Minitest::Test
  def setup
    @key = ENV["DEEPSEEK_API_KEY"]
    unless @key
      File.readlines(File.expand_path("../../llm-proxy/.env", __dir__)).each do |line|
        k, v = line.strip.split("=", 2)
        @key = v.strip.tr("'\"", "") if k == "DEEPSEEK_API_KEY"
      end
    end
  end

  def test_basic_chat
    provider = Ask::Providers::DeepSeek.new(api_key: @key)
    messages = [{ role: "user", content: "Say hi in one word" }]
    response = provider.chat(messages, model: "deepseek-chat", stream: false)
    assert response.content.to_s.length > 0
  end

  def test_chat_with_tools
    provider = Ask::Providers::DeepSeek.new(api_key: @key)
    tool_def = Ask::ToolDef.new(
      name: "get_time",
      description: "Get current time",
      parameters: { type: "object", properties: { tz: { type: "string" } }, required: ["tz"] }
    )
    messages = [{ role: "user", content: "What time is it in UTC?" }]
    response = provider.chat(messages, model: "deepseek-chat", tools: [tool_def], stream: false)
    
    assert response.tool_call?,
      "Expected tool call response but got: #{response.content[..100]}"
    assert response.tool_calls.first[:name] == "get_time",
      "Expected get_time tool call"
  end

  def test_multi_turn_with_tool_result
    provider = Ask::Providers::DeepSeek.new(api_key: @key)
    tool_def = Ask::ToolDef.new(
      name: "get_time",
      description: "Get current time",
      parameters: { type: "object", properties: { tz: { type: "string" } }, required: ["tz"] }
    )

    # Turn 1: User asks, model calls tool
    messages = [{ role: "user", content: "What time is it in UTC?" }]
    response = provider.chat(messages, model: "deepseek-chat", tools: [tool_def], stream: false)
    assert response.tool_call?, "Turn 1 should return a tool call"

    # Extract tool call
    tc = response.tool_calls.first
    messages << { role: :assistant, content: nil, tool_calls: { tc[:id] => OpenStruct.new(tc) } }

    # Turn 2: Tool result, model responds
    messages << { role: :tool, content: "12:00 UTC", tool_call_id: tc[:id] }
    messages << { role: :user, content: "What about London?" }

    response2 = provider.chat(messages.map(&:to_h), model: "deepseek-chat", tools: [tool_def], stream: false)
    assert response2.content.to_s.length > 0 || response2.tool_call?,
      "Turn 2 should respond or call a tool"
  end

  def test_tool_result_streaming
    provider = Ask::Providers::DeepSeek.new(api_key: @key)
    tool_def = Ask::ToolDef.new(
      name: "t",
      description: "A test tool",
      parameters: { type: "object", properties: { c: { type: "string" } }, required: ["c"] }
    )

    messages = [
      { role: "user", content: "hi" },
      { role: :assistant, content: nil,
        tool_calls: { "c1" => OpenStruct.new(id: "c1", name: "t", arguments: '{"c":"test"}') } },
      { role: :tool, content: "done", tool_call_id: "c1" },
      { role: :user, content: "ok" }
    ]

    chunks = []
    response = provider.chat(messages.map(&:to_h), model: "deepseek-chat",
      tools: [tool_def], stream: true) do |chunk|
      chunks << chunk
    end

    assert chunks.any?, "Should receive streaming chunks"
    assert chunks.any? { |c| c.content.to_s.length > 0 || c.tool_calls&.any? },
      "Should have content or tool calls in stream"
  end
end
