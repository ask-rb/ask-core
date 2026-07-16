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
