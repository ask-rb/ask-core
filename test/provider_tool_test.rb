# frozen_string_literal: true

require_relative "test_helper"

class ProviderToolTest < Minitest::Test
  def test_basic_creation
    tool = Ask::ProviderTool.new(id: "openai.web_search", name: "web_search", description: "Search", args: {})
    assert_equal "openai.web_search", tool.id
    assert_equal "web_search", tool.name
    assert_equal "Search", tool.description
    assert_equal ({}), tool.args
  end

  def test_with_args
    tool = Ask::ProviderTool.new(id: "openai.file_search", name: "file_search",
                                  args: { vector_store_ids: ["vs_123"], max_num_results: 5 })
    assert_equal ["vs_123"], tool.args[:vector_store_ids]
    assert_equal 5, tool.args[:max_num_results]
  end

  def test_frozen
    tool = Ask::ProviderTool.new(id: "test", name: "test", args: { key: "value" })
    assert tool.frozen?
    assert tool.args.frozen?
  end

  def test_provider_tool_flag
    tool = Ask::ProviderTool.new(id: "test", name: "test")
    assert tool.provider_tool?
    assert tool.provider_executed?
  end

  def test_web_search_factory
    tool = Ask::ProviderTool.web_search(search_context_size: "high")
    assert_equal "openai.web_search", tool.id
    assert_equal "web_search", tool.name
    assert_equal "high", tool.args[:search_context_size]
  end

  def test_web_search_with_all_options
    tool = Ask::ProviderTool.web_search(
      search_context_size: "medium",
      user_location: { type: "approximate", country: "US" },
      allowed_domains: ["example.com"]
    )
    assert_equal "medium", tool.args[:search_context_size]
    assert_equal "US", tool.args[:user_location][:country]
    assert_equal ["example.com"], tool.args[:allowed_domains]
  end

  def test_web_search_minimal
    tool = Ask::ProviderTool.web_search
    assert_equal "openai.web_search", tool.id
    assert_equal ({}), tool.args
  end

  def test_file_search_factory
    tool = Ask::ProviderTool.file_search(vector_store_ids: ["vs_abc"], max_num_results: 10)
    assert_equal "openai.file_search", tool.id
    assert_equal ["vs_abc"], tool.args[:vector_store_ids]
    assert_equal 10, tool.args[:max_num_results]
  end

  def test_file_search_required_args
    tool = Ask::ProviderTool.file_search(vector_store_ids: ["vs_1", "vs_2"])
    assert_equal ["vs_1", "vs_2"], tool.args[:vector_store_ids]
    assert_nil tool.args[:max_num_results]
  end

  def test_code_interpreter_factory
    tool = Ask::ProviderTool.code_interpreter(file_ids: ["file_1", "file_2"])
    assert_equal "openai.code_interpreter", tool.id
    assert_equal ["file_1", "file_2"], tool.args[:file_ids]
  end

  def test_code_interpreter_no_files
    tool = Ask::ProviderTool.code_interpreter
    assert_equal "openai.code_interpreter", tool.id
    assert_equal ({}), tool.args
  end

  def test_equality
    t1 = Ask::ProviderTool.web_search(search_context_size: "high")
    t2 = Ask::ProviderTool.web_search(search_context_size: "high")
    t3 = Ask::ProviderTool.web_search(search_context_size: "low")
    assert_equal t1, t2
    refute_equal t1, t3
  end

  def test_hash_consistency
    t1 = Ask::ProviderTool.web_search(search_context_size: "high")
    t2 = Ask::ProviderTool.web_search(search_context_size: "high")
    assert_equal t1.hash, t2.hash
  end

end
