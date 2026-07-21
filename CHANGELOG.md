## [0.3.0] — 2026-07-21

### Added

- **Pluggable state abstraction** — `Ask::State::Adapter` defines a unified interface for key-value storage, distributed locking, message queues, and ordered lists. `Ask::State::Memory` provides an in-process, thread-safe implementation backed by Hash.

  ```ruby
  store = Ask::State::Memory.new

  # Key-value with optional TTL
  store.set("key", "value", ttl: 60)
  store.get("key")

  # Distributed locking
  lock = store.acquire_lock("resource", ttl: 10)
  store.release_lock("resource", lock)

  # Message queues
  store.enqueue("queue", { task: "check" })
  store.dequeue("queue")

  # Ordered lists
  store.list_append("list", "item", max_length: 100)
  store.list_range("list", 0, -1)
  store.list_remove("list", "item")
  ```

  The adapter pattern mirrors `Ask::Provider` — define the contract in ask-core, provide implementations in separate gems. Production backends (Redis, PostgreSQL) can be added by any gem without modifying ask-core.

  Data types: `Ask::State::Lock` (with `#expired?`), `Ask::State::QueueEntry`.

### Changed

- **ask-agent's `Persistence::Base` now wraps `Ask::State::Adapter`** — session persistence is backed by the unified state interface instead of a standalone abstract class. `Persistence::InMemory` delegates to `Ask::State::Memory`. Backward compatible — no API changes for users.

### Tested

- 34 new tests for `Ask::State::Adapter` + `Ask::State::Memory`: key-value operations, TTL expiry, thread safety, locking semantics, queue FIFO order, list management, adapter subclassing, and the base class contract.

## [0.2.4] — 2026-07-17

### Added

- **Rich error categories** — `RateLimitError` now carries `category` (`RateLimitCategory::VENDOR` or `::LOCAL`), `rate_limit_type` (`RateLimitType::REQUESTS`, `::TOKENS`, `::CONCURRENT`, `::BUDGET`), and `retry_after` (seconds) for intelligent error handling. Inspired by LiteLLM's error hierarchy.

## [0.2.3] — 2026-07-14

### Changed
- `Ask::ModelCatalog.find(model_id)` now returns `Array<Ask::ModelInfo>` (all matches) — provider preference disambiguation is removed. Provider-scoped `find(model_id, provider)` still returns a single model or raises.
- Removed `Ask::ModelCatalog::PROVIDER_PREFERENCE`. No preference list anywhere — all providers and models are treated equally.

## [0.2.2] — 2026-07-14

### Added
- `Ask::ModelCatalog::PROVIDER_PREFERENCE` — includes `opencode`, `opencode_go`, `mimo` for proper disambiguation of models served by aggregator providers.

## [0.2.1] — 2026-06-25

### Changed
- Testing infrastructure: rubocop, overcommit, bin/setup, gemspec validation, SimpleCov, CI matrix, .minitest config
# Changelog

## 0.2.0 (2026-06-21)

- Added `ToolDef.safe_create` — returns nil instead of raising on invalid tool definitions, with optional log block
- Added `Conversation#find_matching_tool_call` — walks message history to find matching assistant tool call by ID
- Fixed documentation typos and improved YARD annotations

## 0.1.5

- Initial stable release
