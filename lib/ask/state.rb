# frozen_string_literal: true

require "securerandom"
require "forwardable"

module Ask
  # Pluggable state backend for agent sessions, channel providers, and
  # any other ask-rb component that needs durable key-value storage,
  # distributed locking, message queues, or ordered lists.
  #
  # The {State::Adapter} abstract base defines the contract.
  # {State::Memory} provides an in-process implementation backed by Hash.
  # Production apps can provide Redis, PostgreSQL, or other backends by
  # subclassing {State::Adapter}.
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
    end

    # In-process state backend backed by a Hash.
    # All operations are thread-safe via a Mutex.
    # Data is not persisted — lost on process exit.
    class Memory < Adapter
      def initialize
        @data = {}
        @locks = {}
        @queues = {}
        @lists = {}
        @mutex = Mutex.new
      end

      # -- key-value --

      def get(key)
        @mutex.synchronize do
          expiry = @data[key]&.dig(:expires_at)
          return nil if expiry && Time.now >= expiry

          @data[key]&.dig(:value)
        end
      end

      def set(key, value, ttl: nil)
        @mutex.synchronize do
          @data[key] = {
            value: value,
            expires_at: ttl ? Time.now + ttl : nil
          }
        end
      end

      def delete(key)
        @mutex.synchronize { @data.delete(key) }
      end

      def set_if_not_exists(key, value, ttl: nil)
        @mutex.synchronize do
          if @data.key?(key)
            expiry = @data[key][:expires_at]
            return false if expiry.nil? || Time.now < expiry

            # Key expired — treat as nonexistent
            @data.delete(key)
          end

          @data[key] = {
            value: value,
            expires_at: ttl ? Time.now + ttl : nil
          }
          true
        end
      end

      def clear
        @mutex.synchronize do
          @data.clear
          @locks.clear
          @queues.clear
          @lists.clear
        end
      end

      def exists?(key)
        @mutex.synchronize do
          expiry = @data[key]&.dig(:expires_at)
          return false if expiry && Time.now >= expiry
          @data.key?(key)
        end
      end

      def keys(pattern: nil)
        @mutex.synchronize do
          # Filter out expired keys
          active = @data.select do |_k, v|
            expiry = v[:expires_at]
            expiry.nil? || Time.now < expiry
          end

          keys = active.keys.map(&:to_s)
          return keys unless pattern

          regex = glob_to_regex(pattern)
          keys.select { |k| k.match?(regex) }
        end
      end

      # -- locking --

      def acquire_lock(key, ttl: 10)
        @mutex.synchronize do
          existing = @locks[key]
          if existing.nil? || existing.expired?
            lock = Lock.new(
              id: key,
              token: SecureRandom.hex(16),
              expires_at: Time.now + ttl
            )
            @locks[key] = lock
            lock
          end
        end
      end

      def release_lock(key, lock)
        @mutex.synchronize do
          current = @locks[key]
          if current && current.token == lock.token && !current.expired?
            @locks.delete(key)
            true
          else
            false
          end
        end
      end

      # -- queues --

      def enqueue(queue, value)
        @mutex.synchronize do
          @queues[queue] ||= []
          entry = QueueEntry.new(
            id: SecureRandom.uuid,
            value: value,
            enqueued_at: Time.now
          )
          @queues[queue] << entry
          entry
        end
      end

      def dequeue(queue)
        @mutex.synchronize do
          q = @queues[queue]
          return nil unless q&.any?

          q.shift
        end
      end

      def queue_depth(queue)
        @mutex.synchronize do
          (@queues[queue] || []).length
        end
      end

      # -- lists --

      def list_append(key, value, max_length: nil)
        @mutex.synchronize do
          @lists[key] ||= []
          @lists[key] << value
          @lists[key].shift if max_length && @lists[key].length > max_length
        end
      end

      def list_range(key, start = 0, stop = -1)
        @mutex.synchronize do
          list = @lists[key] || []
          return list if start == 0 && stop == -1

          stop = list.length - 1 if stop == -1 || stop >= list.length
          return [] if start > stop

          list[start..stop] || []
        end
      end

      def list_remove(key, value)
        @mutex.synchronize do
          list = @lists[key]
          return 0 unless list

          before = list.length
          list.delete(value)
          before - list.length
        end
      end

      # -- lifecycle --

      def close
        @mutex.synchronize do
          @data.clear
          @locks.clear
          @queues.clear
          @lists.clear
        end
      end

      private

      # Convert a glob pattern (*, ?) to a Regexp.
      def glob_to_regex(pattern)
        escaped = Regexp.escape(pattern)
        regex_str = escaped.gsub("\\*", ".*").gsub("\\?", ".")
        Regexp.new("\\A#{regex_str}\\z")
      end
    end
  end
end
