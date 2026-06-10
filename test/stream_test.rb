# frozen_string_literal: true

require_relative "test_helper"

class StreamTest < Minitest::Test
  def test_chunk_basics
    chunk = Ask::Chunk.new(content: "Hello")
    assert_equal "Hello", chunk.content
    assert_nil chunk.finish_reason
    refute chunk.finished?
    refute chunk.tool_call?
    assert_equal "Hello", chunk.to_s
  end

  def test_chunk_finished
    chunk = Ask::Chunk.new(content: "Done", finish_reason: "stop")
    assert chunk.finished?
    assert_equal "stop", chunk.finish_reason
  end

  def test_chunk_with_tool_calls
    chunk = Ask::Chunk.new(tool_calls: [{ name: "get_weather" }])
    assert chunk.tool_call?
  end

  def test_chunk_with_usage
    chunk = Ask::Chunk.new(usage: { input_tokens: 10, output_tokens: 20 })
    assert_equal 10, chunk.usage[:input_tokens]
  end

  def test_chunk_with_thinking
    chunk = Ask::Chunk.new(thinking: "Model reasoning here")
    assert_equal "Model reasoning here", chunk.thinking
    assert chunk.thinking?
  end

  def test_chunk_without_thinking
    chunk = Ask::Chunk.new(content: "Just text")
    assert_nil chunk.thinking
    refute chunk.thinking?
  end

  def test_chunk_empty_thinking
    chunk = Ask::Chunk.new(thinking: "")
    assert_equal "", chunk.thinking
    refute chunk.thinking?
  end

  def test_chunk_thinking_and_content
    chunk = Ask::Chunk.new(content: "Visible text", thinking: "Hidden reasoning")
    assert_equal "Visible text", chunk.content
    assert_equal "Hidden reasoning", chunk.thinking
    assert chunk.thinking?
  end

  def test_stream_accumulation
    stream = Ask::Stream.new
    stream.add(Ask::Chunk.new(content: "Hello "))
    stream.add(Ask::Chunk.new(content: "World"))
    assert_equal "Hello World", stream.accumulated_text
    assert_equal "Hello World", stream.to_s
  end

  def test_stream_with_string_chunks
    stream = Ask::Stream.new
    stream.add("Hello ")
    stream.add("World")
    assert_equal "Hello World", stream.accumulated_text
  end

  def test_stream_chunk_handler
    chunks = []
    stream = Ask::Stream.new { |chunk| chunks << chunk.content }
    stream.add(Ask::Chunk.new(content: "A"))
    stream.add(Ask::Chunk.new(content: "B"))
    assert_equal %w[A B], chunks
  end

  def test_stream_finish
    stream = Ask::Stream.new
    refute stream.finished?
    stream.finish!
    assert stream.finished?
  end

  def test_stream_each
    stream = Ask::Stream.new
    stream.add(Ask::Chunk.new(content: "A"))
    stream.add(Ask::Chunk.new(content: "B"))

    items = []
    stream.each { |chunk| items << chunk.content }
    assert_equal %w[A B], items
  end

  def test_stream_enumeration
    stream = Ask::Stream.new
    stream.add("x")
    stream.add("y")
    assert_equal %w[x y], stream.map(&:content)
  end

  def test_stream_accumulated_usage
    stream = Ask::Stream.new
    stream.add(Ask::Chunk.new(usage: { input_tokens: 10 }))
    stream.add(Ask::Chunk.new(usage: { output_tokens: 20 }))
    usage = stream.accumulated_usage
    assert_equal 10, usage[:input_tokens]
    assert_equal 20, usage[:output_tokens]
  end

  def test_stream_empty_usage
    stream = Ask::Stream.new
    assert_equal({}, stream.accumulated_usage)
  end

  def test_stream_length
    stream = Ask::Stream.new
    assert_equal 0, stream.length
    stream.add("a")
    stream.add("b")
    assert_equal 2, stream.length
  end

  def test_stream_chunks_returns_copy
    stream = Ask::Stream.new
    stream.add("a")
    chunks = stream.chunks
    chunks << Ask::Chunk.new(content: "b")
    assert_equal 1, stream.length
  end
end
