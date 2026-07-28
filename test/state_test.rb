# frozen_string_literal: true

require_relative "test_helper"

class StateAdapterTest < Minitest::Test
  # Verify the abstract Adapter contract enforces implementation.
  def test_adapter_raises_not_implemented
    adapter = Ask::State::Adapter.new
    assert_raises(NotImplementedError) { adapter.get("key") }
    assert_raises(NotImplementedError) { adapter.set("key", "value") }
    assert_raises(NotImplementedError) { adapter.delete("key") }
    assert_raises(NotImplementedError) { adapter.clear }
    assert_raises(NotImplementedError) { adapter.acquire_lock("key") }
    assert_raises(NotImplementedError) { adapter.release_lock("key", nil) }
    assert_raises(NotImplementedError) { adapter.enqueue("q", "v") }
    assert_raises(NotImplementedError) { adapter.dequeue("q") }
    assert_raises(NotImplementedError) { adapter.list_append("l", "v") }
    assert_raises(NotImplementedError) { adapter.list_range("l") }
  end

  def test_glob_to_like
    assert_equal "prefix%", Ask::State::Adapter.glob_to_like("prefix*")
    assert_equal "prefix_", Ask::State::Adapter.glob_to_like("prefix?")
  end

  def test_glob_to_regex
    regex = Ask::State::Adapter.glob_to_regex("prefix*")
    assert_match regex, "prefix_something"
    refute_match regex, "other_something"
  end

  # Test that exists? returns false for nil by default
  def test_exists_returns_false_when_get_returns_nil
    adapter = Ask::State::Adapter.new
    def adapter.get(key) = nil
    refute adapter.exists?("anything")
  end

  def test_exists_returns_true_when_get_returns_value
    adapter = Ask::State::Adapter.new
    def adapter.get(key) = "value"
    assert adapter.exists?("anything")
  end

  def test_close_is_noop
    Ask::State::Adapter.new.close
  end
end
