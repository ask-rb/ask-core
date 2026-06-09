# Changelog

## 0.1.0 (2026-06-09)

### Added

- `Ask::Provider` — abstract base class for LLM providers with registration and resolution
- `Ask::Conversation` — ordered message container with role normalization
- `Ask::Message` — immutable message with role/content/tool metadata
- `Ask::Stream` / `Ask::Chunk` — streaming primitives for incremental responses
- `Ask::ModelCatalog` / `Ask::ModelInfo` — model registry with models.dev integration
- `Ask::ToolDef` — immutable tool metadata struct for function calling
- `Ask::Result` — standardized tool execution return values
- `Ask::Error` — comprehensive error type hierarchy (18 error classes)
- Zero runtime dependencies (stdlib only)
- >90% test coverage with Minitest (124 tests, 224 assertions)
