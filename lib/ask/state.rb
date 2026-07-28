# frozen_string_literal: true

module Ask
  # Pluggable state backend for agent sessions, channel providers, and
  # any other ask-rb component that needs durable key-value storage,
  # distributed locking, message queues, or ordered lists.
  #
  # The {State::Adapter} abstract base defines the contract.
  # Production apps can provide Redis, PostgreSQL, or other backends by
  # subclassing {State::Adapter}.
  # {State::Memory} (in-process, Hash-backed) is available in the
  # +ask-state-providers+ gem.
  #
  # @example Using the in-memory adapter
  #   store = Ask::State::Memory.new
  #   store.set("key", "value")
  #   store.get("key")     # => "value"
  #   store.delete("key")
  #
  # @example Acquiring a distributed lock
  #   lock = store.acquire_lock("resource-1", ttl: 10)
  #   if lock
  #     begin
  #       # critical section
  #     ensure
  #       store.release_lock("resource-1", lock)
  #     end
  #   end
  #
  # @example Using a message queue
  #   store.enqueue("queue-name", { task: "check_health" })
  #   entry = store.dequeue("queue-name")
  #   # => { id: "uuid", value: { task: "check_health" }, enqueued_at: timestamp }
  module State
    Lock = Data.define(:id, :token, :expires_at) do
      def expired?(now = Time.now)
        expires_at && now >= expires_at
      end
    end

    QueueEntry = Data.define(:id, :value, :enqueued_at)

    # Abstract base class for state backends.
    # Subclasses must implement all methods.
    class Adapter
      # Key-value storage

      # @param key [String] the key
      # @return [Object, nil] the stored value, or nil if not found
      def get(key)
        raise NotImplementedError
      end

      # @param key [String] the key
      # @param value [Object] the value (must be JSON-serializable)
      # @param ttl [Integer, nil] time-to-live in seconds (nil = no expiry)
      def set(key, value, ttl: nil)
        raise NotImplementedError
      end

      # @param key [String] the key
      def delete(key)
        raise NotImplementedError
      end

      # Remove all keys from the store (key-value only by default).
      # Subclasses should override to also clear locks, queues, and lists.
      def clear
        raise NotImplementedError
      end

      # Check if a key exists and has not expired.
      # @param key [String] the key
      # @return [Boolean] true if the key exists and is not expired
      def exists?(key)
        !get(key).nil?
      end

      # Return all non-expired keys, optionally filtered by a glob pattern.
      # Glob syntax: * matches any sequence, ? matches any single character.
      # @param pattern [String, nil] optional glob pattern (e.g., "session:*")
      # @return [Array<String>] matching keys
      def keys(pattern: nil)
        raise NotImplementedError
      end

      # Atomically set a value only if the key does not already exist.
      # @param key [String] the key
      # @param value [Object] the value
      # @return [Boolean] true if the value was set, false if the key already exists
      def set_if_not_exists(key, value, ttl: nil)
        raise NotImplementedError
      end

      # Distributed locking

      # Acquire a lock for a key. Returns nil if the lock is held by another owner.
      # @param key [String] the resource to lock
      # @param ttl [Integer] lock time-to-live in seconds (default 10)
      # @return [Lock, nil] the lock if acquired, nil if already held
      def acquire_lock(key, ttl: 10)
        raise NotImplementedError
      end

      # Release a lock. Only the lock owner can release it.
      # @param key [String] the resource to unlock
      # @param lock [Lock] the lock returned by {#acquire_lock}
      # @return [Boolean] true if released, false if lock was already expired or not held
      def release_lock(key, lock)
        raise NotImplementedError
      end

      # Message queues

      # Push an item onto a named queue.
      # @param queue [String] the queue name
      # @param value [Object] the value to enqueue
      # @return [QueueEntry] the enqueued entry
      def enqueue(queue, value)
        raise NotImplementedError
      end

      # Pop the next item from a named queue.
      # @param queue [String] the queue name
      # @return [QueueEntry, nil] the next entry, or nil if the queue is empty
      def dequeue(queue)
        raise NotImplementedError
      end

      # @param queue [String] the queue name
      # @return [Integer] the number of items in the queue
      def queue_depth(queue)
        raise NotImplementedError
      end

      # Ordered lists

      # Append a value to an ordered list. Trims to max_length (keeps newest).
      # @param key [String] the list key
      # @param value [Object] the value to append
      # @param max_length [Integer, nil] maximum list length (nil = no limit)
      def list_append(key, value, max_length: nil)
        raise NotImplementedError
      end

      # Return a slice of the list.
      # @param key [String] the list key
      # @param start [Integer] starting index (0-based)
      # @param stop [Integer] ending index (inclusive, -1 for all)
      # @return [Array<Object>] the list slice
      def list_range(key, start = 0, stop = -1)
        raise NotImplementedError
      end

      # Remove all occurrences of a value from a list.
      # @param key [String] the list key
      # @param value [Object] the value to remove
      # @return [Integer] number of removed elements
      def list_remove(key, value)
        raise NotImplementedError
      end

      # Lifecycle

      # Optional: called when the adapter is no longer needed.
      def close
        # no-op by default
      end

      # -- Glob pattern helpers --

      # Convert a glob pattern (*, ?) to a SQL LIKE pattern.
      # @param pattern [String] glob pattern (e.g., "session:*")
      # @return [String] LIKE pattern (e.g., "session:%")
      def self.glob_to_like(pattern)
        pattern.gsub("*", "%").gsub("?", "_")
      end

      # Convert a glob pattern (*, ?) to a Regexp.
      # @param pattern [String] glob pattern (e.g., "session:*")
      # @return [Regexp] matching regex (e.g., /\Asession:.*\z/)
      def self.glob_to_regex(pattern)
        escaped = Regexp.escape(pattern)
        Regexp.new("\\A#{escaped.gsub("\\*", ".*").gsub("\\?", ".")}\\z")
      end
    end

  end
end
