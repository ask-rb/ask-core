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

## Release Checklist (Required for v0.1.0)

Before declaring this gem done and releasing v0.1.0, verify:

- [] All tests pass with >90% coverage
- [] Every public API method has documentation (yardoc or inline comments)
- [] README is complete: installation, quick start, configuration, development
- [] CHANGELOG.md exists with an entry for v0.1.0
- [] All code is committed and pushed to github.com/ask-rb/ask-core
- [] Gem builds without errors: gem build *.gemspec
- [] Gem is released as a private gem (see guides/RELEASING.md when available)
- [] A consumer app can install, require, and use the gem with no errors
- [] Thread-safety verified (registry, config, client construction)
- [] Error messages are helpful and actionable

## What Done Means for v0.1.0

The gem reaches v0.1.0 when:
- All implementation steps above are complete and tested
- The gem is released on GitHub Packages as a private gem
- A real consumer can install it with gem install or Bundler
- A consumer script can require it and use its full public API
- The README provides enough information for someone unfamiliar to get started in 5 minutes
- The CHANGELOG documents what v0.1.0 delivers

## Development Workflow

### Git conventions
- Follow the git-workflow skill for branch naming, commit messages, and PR structure.
- Use conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.
- One logical change per commit. No "fixup" or "wip" commits on main.
- Commit messages must be one direct sentence describing the change.

### Reference projects
Study existing implementations for patterns and conventions:

- **ask-tools-shell** — extract from `ruby_llm-conductor/lib/ruby_llm/conductor/tools/`
- **ask-agent** — port from `ruby_llm-conductor/` (session, loop, tool_executor, compactor, etc.)
- **ask-rails** — transform from `solid_agents/` (railtie, generators, persistence)
- **ask-openai, ask-anthropic** — study `ruby_llm/lib/ruby_llm/providers/` for wire formats and streaming patterns
- **ask-openai** — also study `llm-proxy/lib/llm_proxy/protocols/` for OpenAI protocol conversion
- **General patterns** — study `pi/packages/ai/src/providers/` for lazy loading, registration, and protocol families
- **Test patterns** — study `ruby_llm/spec/` for VCR cassette structure and integration testing patterns
- **ask-github** — reference implementation for service context gems; follow its three-file pattern

### Testing
- Use Minitest (not RSpec) — consistent with the ask-rb ecosystem.
- Unit tests for every public method (normal path + edge cases + error cases).
- Integration tests with VCR cassettes for any gem that calls external APIs.
- Run the full suite before every commit: `bundle exec rake test`.
