## [0.4.0] — 2026-07-21

### Added

- **Provider-executed tools** — `Ask::ProviderTool` value objects for configuring built-in tools that run on the LLM provider's infrastructure (web search, file search, code execution). Supports factory methods for OpenAI's built-in tools.

  ```ruby
  Ask::ProviderTool.web_search(search_context_size: "high")
  Ask::ProviderTool.file_search(vector_store_ids: ["vs_abc"], max_num_results: 10)
  Ask::ProviderTool.code_interpreter(file_ids: ["file_1"])
  ```

  Provider tools are identified by a fully qualified `id` (e.g. `"openai.web_search"`) and carry provider-specific `args`. They are `frozen` value objects with equality based on `id` + `args`.

### Changed

- **ask-llm-providers OpenAI** — `chat` now splits provider tools from regular tools. When provider tools are present, the Responses API is used instead of Chat Completions. Regular function tools continue to use the existing Chat Completions path.
- **ask-agent Loop** — `ResponseMessage` now carries `tool_results` for pre-computed provider-executed results. The loop adds them directly to the conversation without local execution, then continues with any remaining user tool calls.
- **ResponseMessage** — `tool_results` field added with default `{}`. All existing call sites are backward compatible via the custom `initialize` with keyword defaults.

### Tested

- 13 new tests for `Ask::ProviderTool`: creation, factory methods, args, frozen, equality, flags.
- 13 new integration tests for provider-executed tools: loop handling with mixed tools, only provider tools, tool splitting in OpenAI provider, Responses API tool formatting.
- Full test suite: 248 ask-core tests, 329 ask-agent tests — 0 failures.

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
