# ask-core

Foundation gem for the ask-rb ecosystem. Provides the types and interfaces that every provider gem builds on.

**Zero external dependencies.** Uses only Ruby stdlib (`json`, `net/http`, `date`, `time`).

## Installation

```ruby
# In your Gemfile
gem "ask-core"
```

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

## Usage

### Provider (abstract base class)

Provider gems subclass `Ask::Provider` and implement the abstract methods:

```ruby
class MyProvider < Ask::Provider
  def api_base
    "https://api.example.com/v1"
  end

  def headers
    { "Authorization" => "Bearer #{@config.api_key}" }
  end

  def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
    # Return an Ask::Message or yield Ask::Chunks
  end

  def embed(text, model:)
    # Return an array of floats
  end

  def list_models
    # Return an array of Ask::ModelInfo
  end

  class << self
    def configuration_options
      [:api_key, :api_base]
    end

    def configuration_requirements
      [:api_key]
    end
  end
end

# Register the provider
Ask::Provider.register(:my_provider, MyProvider)

# Resolve by name
Ask::Provider.resolve(:my_provider) # => MyProvider
```

### Conversation

Build and manipulate conversations with role-normalized messages:

```ruby
conv = Ask::Conversation.new

# Convenience methods
conv.system("You are a helpful assistant.")
conv.user("What's the weather in Tokyo?")
conv.assistant("Let me check...", tool_calls: [{ name: "get_weather", arguments: { location: "Tokyo" } }])
conv.tool_result("72°F, sunny", tool_call_id: "call_123")

# Iteration
conv.each { |msg| puts "#{msg.role}: #{msg.content}" }

# Filtering by role
conv.user_messages   # => [Ask::Message, ...]
conv.system_messages # => [Ask::Message, ...]

# Serialization
conv.to_a # => [{ role: :user, content: "..." }, ...]
```

### Messages

```ruby
msg = Ask::Message.new(role: :user, content: "Hello")
msg.user?      # => true
msg.system?    # => false
msg.assistant? # => false
msg.tool?      # => false

msg = Ask::Message.new(role: :assistant, tool_calls: [{ name: "f", arguments: {} }])
msg.tool_call? # => true

msg = Ask::Message.new(role: :tool, content: "result", tool_call_id: "call_1")
msg.tool_result? # => true
```

Valid roles: `:system`, `:user`, `:assistant`, `:tool`

### Streaming

```ruby
stream = Ask::Stream.new

# Add chunks as they arrive from the provider
stream.add(Ask::Chunk.new(content: "Hello "))
stream.add(Ask::Chunk.new(content: "World"))
stream.add(Ask::Chunk.new(content: "", finish_reason: "stop"))
stream.finish!

# Accumulate the full response
stream.accumulated_text # => "Hello World"
stream.to_s             # => "Hello World"

# Track token usage
stream.accumulated_usage # => { input_tokens: 10, output_tokens: 20 }

# Iterate
stream.each { |chunk| print chunk.content }
```

### Chunks

```ruby
chunk = Ask::Chunk.new(content: "Hello")
chunk.content        # => "Hello"
chunk.finished?      # => false
chunk.tool_call?     # => false
chunk.finish_reason  # => nil (or "stop", "length", "tool_calls")

chunk = Ask::Chunk.new(tool_calls: [{ name: "get_weather" }])
chunk.tool_call?     # => true

chunk = Ask::Chunk.new(usage: { input_tokens: 10, output_tokens: 20 })
chunk.usage          # => { input_tokens: 10, output_tokens: 20 }
```

### Model Catalog

Query available models from the registry:

```ruby
catalog = Ask::ModelCatalog.new([
  Ask::ModelInfo.new(id: "gpt-4o", provider: "openai", capabilities: ["function_calling", "vision"]),
  Ask::ModelInfo.new(id: "claude-sonnet-4", provider: "anthropic", capabilities: ["function_calling", "reasoning"])
])

# Find by ID (prefers most common provider)
catalog.find("gpt-4o")

# Find with specific provider
catalog.find("gpt-4o", "openai")

# Filter by type
catalog.chat_models
catalog.embedding_models

# Filter by provider or family
catalog.by_provider("openai")
catalog.by_family("gpt")

# Singleton instance
Ask::ModelCatalog.instance
Ask::ModelCatalog.find("gpt-4o")
```

### ModelInfo

```ruby
info = Ask::ModelInfo.new(
  id: "gpt-4o",
  provider: "openai",
  capabilities: ["function_calling", "vision"],
  context_window: 128_000,
  pricing: { text_tokens: { standard: { input_per_million: 2.5, output_per_million: 10 } } }
)

info.supports?(:function_calling)    # => true
info.chat?                           # => true
info.embedding?                      # => false
info.context_window                  # => 128_000
```

### Tool Definitions

Immutable tool metadata for provider function calling:

```ruby
tool = Ask::ToolDef.new(
  name: "get_weather",
  description: "Get current weather for a location",
  parameters: {
    type: "object",
    properties: {
      location: { type: "string", description: "City name" },
      unit: { type: "string", enum: ["celsius", "fahrenheit"] }
    },
    required: ["location"]
  }
)

tool.name         # => "get_weather"
tool.description  # => "Get current weather for a location"

# Provider-specific format
tool.to_provider_format { |t| { type: "function", function: t.to_h } }
```

### Tool Results

Standardized return values from tool execution:

```ruby
Ask::Result.success("Data processed")
Ask::Result.success(updated_record, metadata: { duration: 1.2 })
Ask::Result.failure("API returned 500", error: "Timeout")
Ask::Result.aborted("Cancelled by sibling failure")
Ask::Result.blocked("Permission denied")

result = Ask::Result.success("OK")
result.success?  # => true
result.error?    # => false
result.aborted?  # => false
result.blocked?  # => false
result.to_s      # => "OK"
result.to_h      # => { content: "OK", status: :success, metadata: {} }
```

### Error Types

```ruby
Ask::Error                  # Base class (rescue Ask::Error to catch all)
Ask::ConfigurationError     # Missing/incorrect configuration
Ask::UnknownProvider        # Provider not registered
Ask::ModelNotFound          # Model not in catalog
Ask::InvalidRole            # Invalid message role
Ask::InvalidToolDefinition  # Invalid tool name/definition
Ask::ProviderError          # Provider API error (with status_code, response_body)
Ask::ContextLengthExceeded  # Context window exceeded
Ask::RateLimitError         # Rate limited
Ask::Unauthorized           # Authentication failure
Ask::ServerError            # 5xx server error
Ask::ServiceUnavailable     # Service temporarily unavailable
Ask::UnsupportedFeature     # Feature not supported by provider/model
Ask::MissingCredential      # Required credential not found
Ask::InvalidCredential      # Credential is invalid/expired
```

## Development

```bash
bundle exec rake test
```

## Testing

- Uses Minitest (not RSpec) — consistent with the ask-rb ecosystem.
- Unit tests for every public method.
- Run the full suite before every commit: `bundle exec rake test`.

## Design Principles

1. **Zero runtime dependencies** — stdlib only. Provider gems add their own HTTP clients.
2. **Immutable value objects** — `Message`, `ToolDef`, `Result`, `Chunk`, and `ModelInfo` are frozen after construction.
3. **Abstract interface** — `Ask::Provider` defines the contract. Provider gems implement the wire format.
4. **Provider registry** — providers register themselves for runtime resolution by name.

## License

MIT
