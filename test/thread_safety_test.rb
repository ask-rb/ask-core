# frozen_string_literal: true

require_relative "test_helper"

class ThreadSafetyTest < Minitest::Test
  include TestHelpers

  def setup
    Ask::Provider.clear_providers!
  end

  def teardown
    Ask::Provider.clear_providers!
  end

  def test_concurrent_registration
    threads = 10.times.map do |i|
      Thread.new do
        klass = stub_provider_class(name: "Provider#{i}")
        Ask::Provider.register("provider_#{i}".to_sym, klass)
      end
    end
    threads.each(&:join)

    assert_equal 10, Ask::Provider.providers.size
  end

  def test_concurrent_resolution
    klass = stub_provider_class
    10.times { |i| Ask::Provider.register("p#{i}".to_sym, klass) }

    threads = 10.times.map do |i|
      Thread.new do
        Ask::Provider.resolve("p#{i}".to_sym)
      end
    end
    results = threads.map(&:value)

    assert_equal 10, results.compact.size
    results.each { |r| refute_nil r }
  end

  def test_concurrent_model_catalog_access
    model = Ask::ModelInfo.new(id: "test", provider: "openai")
    catalog = Ask::ModelCatalog.new([model])

    threads = 10.times.map do
      Thread.new do
        100.times do
          catalog.find("test")
          catalog.length
          catalog.chat_models
        end
      end
    end
    threads.each(&:join)

    assert_equal 1, catalog.length
  end

  def test_concurrent_stream_usage
    stream = Ask::Stream.new

    writer = Thread.new do
      100.times { |i| stream.add("chunk-#{i}") }
      stream.finish!
    end

    reader = Thread.new do
      sleep 0.01
      chunks = []
      stream.each { |c| chunks << c }
      chunks
    end

    writer.join
    reader.join

    assert stream.finished?
    assert stream.length <= 100
  end

  def test_conversation_thread_safe_reading
    conv = Ask::Conversation.new
    10.times { |i| conv.user("Message #{i}") }

    threads = 10.times.map do
      Thread.new do
        100.times do
          conv.length
          conv.to_a
          conv.last
          conv.by_role(:user)
        end
      end
    end
    threads.each(&:join)

    assert_equal 10, conv.length
  end

  def test_tool_def_concurrent_creation
    tools = []
    mutex = Mutex.new

    threads = 10.times.map do |i|
      Thread.new do
        tool = Ask::ToolDef.new(name: "tool_#{i}")
        mutex.synchronize { tools << tool }
      end
    end
    threads.each(&:join)

    assert_equal 10, tools.size
    assert tools.all?(&:frozen?)
  end

  def test_result_concurrent_creation
    results = []
    mutex = Mutex.new

    threads = 10.times.map do
      Thread.new do
        r = Ask::Result.success("ok")
        mutex.synchronize { results << r }
      end
    end
    threads.each(&:join)

    assert_equal 10, results.size
    assert results.all?(&:frozen?)
  end
end
