## [0.10.0] - 2026-08-05

### Added

- **`Ask::Result.pending`** — a new `:pending` status for async tool
  execution. A tool returns pending to hand the turn back to the agent
  (the interim message gets voiced) while the real work continues in the
  background; the session completes it later. `Result#pending?` predicates
  it; `to_h` keeps the tool shape.

## [0.9.0] — 2026-08-03

### Changed

- **`Ask::Result` is now the single result type for the whole ecosystem** — it
  supports both the foundational API (`success`/`failure`/`aborted`/`blocked`
  with `content` and `status`) and the tool API (`ok`/`error` with `ok?`,
  `output`, and `error_message`), including both constructor keyword sets.
  Previously `ask-tools` defined its own incompatible `Ask::Result`; whichever
  gem loaded last won, so `Ask::Result.success` raised `ArgumentError` in any
  app loading both (e.g. every ask-agent app), and `ask-rag`'s `raw.output`
  call failed on provider embedding results. ask-tools now depends on
  ask-core instead of redefining the class.
- `Result#to_h` now serializes to `{ok:, output:, error:, metadata:}` (the
  tool shape). `Result#inspect` is `ok=true output=...` / `ok=false error=...`.

  ```ruby
  Ask::Result.success("Data processed").to_h
  # => {ok: true, output: "Data processed", error: nil, metadata: {}}

  Ask::Result.ok(data: "Data processed")   # same class, same result
  ```

### Tested

- ask-core test suite: all pass.

## [0.8.0] — 2026-07-28

### Changed

- **`Ask::State::Memory` moved to `ask-state-providers`** — `ask-core` now only contains the abstract `State::Adapter` contract. The in-memory implementation is available in the `ask-state-providers` gem under the same class name (`Ask::State::Memory`). This keeps `ask-core` purely foundational.

  ```ruby
  # Before (ask-core 0.7.x)
  require "ask"
  store = Ask::State::Memory.new

  # After — add ask-state-providers gem
  require "ask-state-providers"
  store = Ask::State::Memory.new  # same class name, same API
  ```

### Tested

- 281 tests, 549 assertions, 0 failures

## [0.7.0] — 2026-07-26

### Added

- **Multi-modal content types** — `Ask::Content` module with `Text`, `Image`, `Audio`, `Video`, and `File` value objects. Each is frozen, comparable, and serializable via `#to_h`.

  ```ruby
  Ask::Content::Text.new("What's in this image?")
  Ask::Content::Image.new(url: "https://example.com/photo.jpg", mime_type: "image/jpeg")
  Ask::Content::Audio.new(url: "https://example.com/audio.mp3", mime_type: "audio/mpeg")
  Ask::Content::Video.new(url: "https://example.com/video.mp4", mime_type: "video/mp4")
  Ask::Content::File.new(data: "file content", mime_type: "text/plain", filename: "notes.txt")
  ```

- **`Ask::Message#content_blocks`** — `Message` now accepts an Array of `Ask::Content` objects as `content:`. The `#content` accessor still returns the plain text for backward compatibility. `#content_blocks` returns the structured blocks, `#multimodal?` checks for non-text blocks.

  ```ruby
  msg = Ask::Message.new(role: :user, content: [
    Ask::Content::Text.new("What's in this image?"),
    Ask::Content::Image.new(url: "https://example.com/photo.jpg", mime_type: "image/jpeg")
  ])
  msg.multimodal?      # => true
  msg.content_blocks   # => [Text("What's in this image?"), Image(...)]
  msg.content          # => "What's in this image?"
  ```

- **`Ask::Conversation`** — `#user` and `#system` now accept arrays of content blocks directly. `#dup` correctly handles content blocks.

- **`Ask::Content::Block`** — shared base module for all content types. Content blocks respond to `#to_h` for serialization.

### Changed

- `Ask::Message#to_h` now serializes content blocks as an array of typed hashes (`{ type: "text", text: "..." }`, `{ type: "image", url: "...", mime_type: "..." }`, etc.) when the message has content_blocks.
- `Ask::Message#inspect` updated to show `multimodal`, `rich`, or `text` label.

### Tested

- 311 tests, 611 assertions, 0 failures
- 69 new tests for Content types, multi-modal messages, serialization, equality, and Conversation integration

## [0.6.0] — 2026-07-26: loaded by document loaders, split by text splitters, embedded and retrieved by vector stores. Immutable, equality-checked by content+metadata, and JSON-serializable.

  ```ruby
  doc = Ask::Document.new(
    content: "Ruby was created by Matz in 1995.",
    metadata: { source: "history.pdf", page: 3 }
  )
  doc.content   # => "Ruby was created by Matz in 1995."
  doc.metadata  # => { source: "history.pdf", page: 3 }
  doc.to_h      # => { content: "...", metadata: { source: "history.pdf", page: 3 } }
  ```

## [0.5.0] — 2026-07-22

### Added

- `Ask::CostCalculator` — compute API costs from model pricing data.

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
