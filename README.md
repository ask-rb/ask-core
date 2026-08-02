# ask-core

[![Gem Version](https://badge.fury.io/rb/ask-core.svg)](https://badge.fury.io/rb/ask-core)

Foundation gem for the ask-rb ecosystem. Provides the value objects and interfaces every other gem builds on: messages, conversations, streaming primitives, the provider contract, model catalog, tool definitions, and structured errors. Zero external dependencies, Ruby stdlib only (`json`, `net/http`, `date`, `time`).

## Installation

```ruby
gem "ask-core"
```

## Quick Start

```ruby
require "ask-core"

conv = Ask::Conversation.new
conv.system("You are a helpful assistant.")
conv.user("What's the weather in Tokyo?")

conv.last.role    # => :user
conv.last.user?   # => true

# Serialize for a provider API
conv.to_a         # => [{ role: :user, content: "..." }, ...]
```

## The core types

| Type | Purpose |
|---|---|
| `Ask::Conversation`, `Ask::Message` | Message container with role normalization (`:system`, `:user`, `:assistant`, `:tool`) and immutable message value objects |
| `Ask::Stream`, `Ask::Chunk` | Streaming primitives with text accumulation and usage tracking |
| `Ask::Provider` | Abstract base class for LLM providers, with a thread-safe registry (`register` / `resolve`) |
| `Ask::ModelCatalog`, `Ask::ModelInfo` | Model metadata: find by ID/provider, filter by family, refresh from models.dev |
| `Ask::ToolDef` | Immutable tool metadata for provider function calling |
| `Ask::Result` | Standardized tool return value: `success`, `failure`, `aborted`, `blocked` |
| `Ask::Content` | Multi-modal content blocks: `Text`, `Image`, `Audio`, `Video`, `File` |
| `Ask::Document` | Text + metadata value object for RAG pipelines |
| `Ask::ProviderTool` | Provider-executed tools (e.g. `web_search`, `file_search`) |
| `Ask::State::Adapter` | Abstract contract for state backends (implemented by ask-state-providers) |
| `Ask::Error` and subclasses | Structured errors (`ConfigurationError`, `RateLimitError`, `ProviderError`, and more) |

## Defining a provider

Provider gems subclass `Ask::Provider`, implement the abstract methods, and register themselves:

```ruby
class MyProvider < Ask::Provider
  def api_base = "https://api.example.com/v1"
  def chat(messages, model:, **opts) = Ask::Message.new(role: :assistant, content: "Hello")
  def embed(text, model:) = [0.1, 0.2, 0.3]
  def list_models = [Ask::ModelInfo.new(id: "my-model", provider: "my_provider")]
end

Ask::Provider.register(:my_provider, MyProvider)
Ask::Provider.resolve(:my_provider)  # => MyProvider
```

## Full documentation

The full ask-rb documentation lives at https://ask-rb.github.io/ask-docs. [ask-core in depth](https://ask-rb.github.io/ask-docs/core/ask-core) covers the types, streaming, and the provider contract. API reference: https://ask-rb.github.io/ask-docs/reference/api.

## Development

```
bundle install
bundle exec rake test
```

## License

MIT
