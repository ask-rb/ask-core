# ask-core — Foundation Gem

## Purpose

The foundation gem that every provider gem depends on. Defines the types and interfaces
everything builds on. Eventually replaces `ruby_llm`'s role in the ask-rb stack.

**IMPORTANT:** This gem is Phase 3 of the migration plan. Do NOT build until ask-tools,
ask-tools-shell, ask-auth, ask-agent, ask-rails, and ask-tools-* service gems are all
shipped and stable. The agent stack depends on `ruby_llm` until this gem exists.

## Dependencies

- **Runtime:** none (stdlib only)
- **Build/test:** minitest, mocha, rake
- **No other ask-rb gems required.** This is the shared foundation.

## What it provides

| Component | File | Purpose |
|---|---|---|
| `Ask::Provider` | `lib/ask/provider.rb` | Abstract base class for all LLM providers |
| `Ask::Conversation` | `lib/ask/conversation.rb` | Message container with role normalization |
| `Ask::Stream` / `Ask::Chunk` | `lib/ask/stream.rb` | Streaming primitives |
| `Ask::ModelCatalog` | `lib/ask/models.rb` | Model name to provider resolution |
| `Ask::ToolDef` | `lib/ask/tool_def.rb` | Immutable tool metadata struct |
| `Ask::Result` | `lib/ask/result.rb` | Standardized tool return value |
| `Ask::Error` | `lib/ask/errors.rb` | Structured error types |

## Implementation Steps

### 1. Define gem scaffold
- `lib/ask-core.rb` — entry point, requires all components
- `lib/ask/version.rb` — version constant
- `ask-core.gemspec` — zero runtime dependencies
- Zeitwerk or manual require ordering

### 2. Build Ask::Error types (`lib/ask/errors.rb`)
- `Ask::Error` base class
- `Ask::MissingCredential` — no API key found
- `Ask::InvalidCredential` — API key rejected by provider
- `Ask::ProviderError` — provider returned error
- `Ask::RateLimitError` — rate limited
- `Ask::ContextLengthExceededError` — too many tokens
- Each error should carry the provider name and helpful message

### 3. Build Ask::Result (`lib/ask/result.rb`)
- Value object with `ok?`, `output`, `error`, `metadata` attributes
- Factory: `Ask::Result.ok(data:)`, `Ask::Result.error(message:)`
- Implements `to_s` for display, `to_h` for serialization
- This is the shared return type for both tools AND provider calls

### 4. Build Ask::Conversation (`lib/ask/conversation.rb`)
- Message container: `add_message(role:, content:, tool_calls:, tool_call_id:)`
- Supported roles: `system`, `user`, `assistant`, `tool`
- `to_a` — serialize to array of hashes ready for provider API call
- Role normalization: `Ask::RoleMap.normalize("developer")` → `"system"`
- Support for multi-content messages (text + images)
- `messages` — access the accumulated messages

### 5. Build Ask::Stream / Ask::Chunk (`lib/ask/stream.rb`)
- `Ask::Stream` — enumerable wrapper around async stream
- `each { |chunk| ... }` — iterate over chunks
- `transcript` — full accumulated response
- `Ask::Chunk` — value object with `content`, `tool_calls`, `delta` fields
- Support for text deltas, tool call deltas, and completion signals

### 6. Build Ask::ToolDef (`lib/ask/tool_def.rb`)
- Immutable struct: `name`, `description`, `parameters` (JSON Schema hash)
- Constructor from a tool instance: `Ask::ToolDef.from(tool)`
- Serialization: `to_h` for provider API format

### 7. Build Ask::Provider (`lib/ask/provider.rb`)
- Abstract base class that all provider gems implement
- Interface:
  - `chat(conversation, tools:, model:, &stream_block)` — chat completion
  - `chat_with_tools(conversation, tools:, model:, &stream_block)` — with functions
  - `chat_simple(messages, model:)` — no tools, no streaming
  - `embed(texts, model:)` — embeddings
  - Configured? check, model info query
- Define the interface with keyword args and clear documentation
- Provider registry: `Ask::Provider.register(name, klass)`
- Model resolution: `Ask::Provider.for("gpt-4o")` → finds provider from catalog

### 8. Build Ask::ModelCatalog (`lib/ask/models.rb`)
- Model name → provider mapping
- `Ask::Models.find("gpt-4o")` → `{provider: :openai, model_id: "gpt-4o"}`
- `Ask::Models.find("claude-sonnet-4-5")` → `{provider: :anthropic, model_id: "claude-sonnet-4-5"}`
- Static catalog (hardcoded mapping for known models)
- Fallback: prefix-based matching for unknown models ("claude-*" → anthropic)
- Extensible: provider gems register their models on load

### 9. Build Ask::Response (`lib/ask/response.rb`)
- Value object returned by provider.chat (when not streaming)
- Attributes: `message`, `tool_calls`, `usage` (input/output tokens, cost)
- `content` — text content of the response
- `model` — model that was used

### 10. Test coverage
- Test Conversation: add messages, serialize to array, role normalization
- Test Stream: stream chunks, accumulate transcript
- Test Result: ok/error construction, serialization
- Test ToolDef: construction, serialization, from tool
- Test ModelCatalog: model resolution, prefix fallback, registration
- Test Provider base: subclass must implement interface, registry works
- Test Errors: each error type carries correct info
- Test Response: message content, tool calls, usage tracking

### 11. README
- Installation
- Architecture overview with gem map
- Provider interface documentation
- Conversation and streaming API
- Error handling guide

## What "Done" Means

- All types implemented and tested
- Ask::Provider defines interface that provider gems can implement
- Ask::Conversation serializes messages correctly for all provider formats
- Ask::Stream works with both synchronous and streaming responses
- Ask::ModelCatalog can resolve model names to providers
- Zero runtime dependencies
- >90% test coverage
- README documents the full API
- Provider gems can be written against this interface **without changes to the interface**
