# ask-core

Foundation gem for the ask-rb ecosystem. Provides the types and interfaces
that every provider gem builds on: Ask::Provider (abstract base class),
Ask::Conversation, Ask::Stream, Ask::ModelCatalog, and Ask::ToolDef.

Zero external dependencies.

## Installation

```ruby
gem "ask-core"
```

## What it provides

- Ask::Provider — abstract base class for all LLM providers
- Ask::Conversation — message container with role normalization
- Ask::Stream / Ask::Chunk — streaming primitives
- Ask::ModelCatalog — model name to provider resolution
- Ask::ToolDef — tool definition metadata
- Ask::Error — structured error types

## Development

```bash
bundle exec rake test
```

## License

MIT
