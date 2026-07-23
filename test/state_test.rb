# frozen_string_literal: true

require_relative "test_helper"

class StateTest < Minitest::Test
  def setup
    @store = Ask::State::Memory.new
  end

  def teardown
    @store.close
  end

  # -- Key-value --

  def test_get_set
    @store.set("name", "Alice")
    assert_equal "Alice", @store.get("name")
  end

  def test_get_missing
    assert_nil @store.get("nonexistent")
  end

  def test_set_overwrites
    @store.set("key", "first")
    @store.set("key", "second")
    assert_equal "second", @store.get("key")
  end

  def test_delete
    @store.set("key", "value")
    @store.delete("key")
    assert_nil @store.get("key")
  end

  def test_delete_missing
    @store.delete("nonexistent") # should not raise
  end

  def test_set_with_ttl
    @store.set("temp", "value", ttl: 0.01)
    assert_equal "value", @store.get("temp")
    sleep 0.02
    assert_nil @store.get("temp")
  end

  def test_set_with_nil_ttl
    @store.set("perm", "forever", ttl: nil)
    assert_equal "forever", @store.get("perm")
  end

  def test_set_if_not_exists_success
    assert @store.set_if_not_exists("key", "first")
    assert_equal "first", @store.get("key")
  end

  def test_set_if_not_exists_fails_on_existing
    @store.set("key", "original")
    refute @store.set_if_not_exists("key", "second")
    assert_equal "original", @store.get("key")
  end

  def test_set_if_not_exists_reclaims_expired_key
    @store.set("key", "original", ttl: 0.01)
    sleep 0.02
    assert @store.set_if_not_exists("key", "reclaimed")
    assert_equal "reclaimed", @store.get("key")
  end

  def test_key_value_thread_safety
    threads = 10.times.map do
      Thread.new do
        20.times { @store.set("counter", @store.get("counter").to_i + 1) }
      end
    end
    threads.each(&:join)
    # With mutex protection, the counter should be correct
    assert_equal 200, @store.get("counter")
  end

  # -- Locking --

  def test_acquire_lock
    lock = @store.acquire_lock("resource", ttl: 10)
    refute_nil lock
    assert_equal "resource", lock.id
    refute_nil lock.token
    refute_nil lock.expires_at
  end

  def test_acquire_lock_fails_if_held
    @store.acquire_lock("resource", ttl: 10)
    assert_nil @store.acquire_lock("resource", ttl: 10)
  end

  def test_release_lock
    lock = @store.acquire_lock("resource", ttl: 10)
    assert @store.release_lock("resource", lock)
    refute_nil @store.acquire_lock("resource", ttl: 10)
  end

  def test_release_lock_wrong_token
    lock = @store.acquire_lock("resource", ttl: 10)
    wrong = Ask::State::Lock.new(id: "resource", token: "wrong-token", expires_at: Time.now + 10)
    refute @store.release_lock("resource", wrong)
    assert_nil @store.acquire_lock("resource", ttl: 10), "Lock should still be held"
  end

  def test_lock_expires
    lock = @store.acquire_lock("resource", ttl: 0.01)
    refute_nil lock
    sleep 0.02
    assert lock.expired?
    # Expired lock can be reacquired
    refute_nil @store.acquire_lock("resource", ttl: 10)
  end

  def test_lock_expired_check
    future = Ask::State::Lock.new(id: "r", token: "t", expires_at: Time.now + 3600)
    refute future.expired?

    past = Ask::State::Lock.new(id: "r", token: "t", expires_at: Time.now - 10)
    assert past.expired?
  end

  def test_lock_data_object
    lock = @store.acquire_lock("r", ttl: 5)
    assert_instance_of Ask::State::Lock, lock
    assert_respond_to lock, :id
    assert_respond_to lock, :token
    assert_respond_to lock, :expires_at
    assert_respond_to lock, :expired?
  end

  # -- Queues --

  def test_enqueue_dequeue
    entry = @store.enqueue("tasks", { job: "test" })
    assert_instance_of Ask::State::QueueEntry, entry
    assert entry.id
    assert_equal "test", entry.value[:job]
    assert entry.enqueued_at
  end

  def test_dequeue_returns_in_order
    @store.enqueue("q", "first")
    @store.enqueue("q", "second")
    assert_equal "first", @store.dequeue("q").value
    assert_equal "second", @store.dequeue("q").value
  end

  def test_dequeue_empty
    assert_nil @store.dequeue("empty")
  end

  def test_queue_depth
    assert_equal 0, @store.queue_depth("q")
    @store.enqueue("q", "a")
    assert_equal 1, @store.queue_depth("q")
    @store.enqueue("q", "b")
    assert_equal 2, @store.queue_depth("q")
    @store.dequeue("q")
    assert_equal 1, @store.queue_depth("q")
    @store.dequeue("q")
    assert_equal 0, @store.queue_depth("q")
  end

  def test_separate_queues
    @store.enqueue("q1", "a")
    @store.enqueue("q2", "b")
    assert_equal "a", @store.dequeue("q1").value
    assert_equal "b", @store.dequeue("q2").value
  end

  def test_queue_entry_data_object
    entry = @store.enqueue("q", { x: 1 })
    assert_instance_of Ask::State::QueueEntry, entry
    assert_respond_to entry, :id
    assert_respond_to entry, :value
    assert_respond_to entry, :enqueued_at
  end

  # -- Lists --

  def test_list_append_and_range
    @store.list_append("list", "a")
    @store.list_append("list", "b")
    @store.list_append("list", "c")
    assert_equal %w[a b c], @store.list_range("list")
  end

  def test_list_range_slice
    @store.list_append("list", "a")
    @store.list_append("list", "b")
    @store.list_append("list", "c")
    @store.list_append("list", "d")
    assert_equal %w[b c], @store.list_range("list", 1, 2)
  end

  def test_list_range_empty
    assert_equal [], @store.list_range("nonexistent")
  end

  def test_list_append_with_max_length
    5.times { |i| @store.list_append("limited", i, max_length: 3) }
    assert_equal [2, 3, 4], @store.list_range("limited")
  end

  def test_list_remove
    @store.list_append("list", "a")
    @store.list_append("list", "b")
    @store.list_append("list", "a")
    assert_equal 2, @store.list_remove("list", "a")
    assert_equal %w[b], @store.list_range("list")
  end

  def test_list_remove_nonexistent
    @store.list_append("list", "a")
    assert_equal 0, @store.list_remove("list", "x")
    assert_equal %w[a], @store.list_range("list")
  end

  def test_list_remove_empty
    assert_equal 0, @store.list_remove("empty", "x")
  end

  # -- Lifecycle --

  def test_close_clears_all_data
    @store.set("key", "value")
    @store.acquire_lock("lock", ttl: 10)
    @store.enqueue("q", "item")
    @store.list_append("list", "a")
    @store.close

    assert_nil @store.get("key")
    assert_nil @store.dequeue("q")
    assert_equal [], @store.list_range("list")
  end

  # -- Adapter interface --

  def test_clear
    @store.set("a", 1)
    @store.set("b", 2)
    @store.clear
    assert_nil @store.get("a")
    assert_nil @store.get("b")
  end

  def test_clear_empty_store
    @store.clear
    assert_nil @store.get("anything")
  end

  def test_adapter_base_raises_not_implemented
    adapter = Ask::State::Adapter.new
    assert_raises(NotImplementedError) { adapter.get("k") }
    assert_raises(NotImplementedError) { adapter.set("k", "v") }
    assert_raises(NotImplementedError) { adapter.delete("k") }
    assert_raises(NotImplementedError) { adapter.set_if_not_exists("k", "v") }
    assert_raises(NotImplementedError) { adapter.clear }
    assert_raises(NotImplementedError) { adapter.acquire_lock("k") }
    assert_raises(NotImplementedError) { adapter.release_lock("k", nil) }
    assert_raises(NotImplementedError) { adapter.enqueue("q", "v") }
    assert_raises(NotImplementedError) { adapter.dequeue("q") }
    assert_raises(NotImplementedError) { adapter.queue_depth("q") }
    assert_raises(NotImplementedError) { adapter.list_append("k", "v") }
    assert_raises(NotImplementedError) { adapter.list_range("k") }
    assert_raises(NotImplementedError) { adapter.list_remove("k", "v") }
    adapter.close # should not raise (default no-op)
  end

  # -- Custom adapter subclass --

  def test_custom_adapter
    custom = Class.new(Ask::State::Adapter) do
      def initialize
        @store = {}
      end
      def get(key) = @store[key]
      def set(key, value, ttl: nil) = (@store[key] = value)
      def delete(key) = @store.delete(key)
    end.new

    custom.set("k", "custom")
    assert_equal "custom", custom.get("k")
  end
end
