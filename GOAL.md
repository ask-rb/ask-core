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
## External Services We Reuse (Do Not Rebuild)

We are building a Ruby-agent framework, not a global model registry, not provider APIs,
not OAuth infrastructure. These services already exist and are proven in production.
We call them — we do not rebuild them.

---

### 1. Model Metadata: models.dev

- **URL:** https://models.dev/api.json
- **Used by:** RubyLLM (production, every request)
- **What it provides:** Model names, provider mapping, capabilities (function_calling,
  structured_output, reasoning, vision), modalities (text, image, audio, pdf, video),
  pricing (input/output tokens, cache read/write), context window sizes, rate limits.
- **Why we use it:** Without it we would need to maintain a static JSON file manually
  and update it every time a new model is released. models.dev is updated by the
  community and covers all major providers.
- **How we use it:** Ask::Models.fetch_on_refresh() calls this API, caches the result,
  merges with provider-registered models. See ruby_llm/lib/ruby_llm/models.rb:
  fetch_models_dev_models() for the reference implementation.
- **Fallback:** If models.dev is unreachable, we use the last cached response.
  If no cache exists, we fall back to models registered by installed providers.

---

### 2. Provider Chat APIs (implemented by ask-llm-providers)

These are the actual LLM endpoints. We implement HTTP clients for them, we do not
rebuild them. Each is documented in its specific provider implementation.

**OpenAI + Compatible Family** (Ask::Provider::OpenAI):
| Provider | Base URL |
|---|---|
| OpenAI | https://api.openai.com/v1 |
| OpenRouter | https://openrouter.ai/api/v1 |
| DeepSeek | https://api.deepseek.com |
| XAI / Grok | https://api.x.ai/v1 |
| Perplexity | https://api.perplexity.ai |
| Azure OpenAI | https://{resource}.openai.azure.com/openai/v1 |
| Cerebras | https://api.cerebras.ai/v1 |
| Fireworks | https://api.fireworks.ai/inference |
| Groq | https://api.groq.com/openai/v1 |
| Together | https://api.together.ai/v1 |
| Moonshot | https://api.moonshot.ai/v1 |

**Reference:** ruby_llm/lib/ruby_llm/providers/openai/ — Chat Completions + Responses API
  llm-proxy/lib/llm_proxy/protocols/ — protocol normalization
  pi/packages/ai/src/providers/openai-completions.ts — alternate implementations

**Anthropic** (Ask::Provider::Anthropic):
- Base URL: https://api.anthropic.com
- Endpoint: /v1/messages
- Reference: ruby_llm/lib/ruby_llm/providers/anthropic/

**Google Gemini** (Ask::Provider::Google):
- Base URL: https://generativelanguage.googleapis.com/v1beta
- Reference: ruby_llm/lib/ruby_llm/providers/gemini/

**Google Vertex AI** (Ask::Provider::VertexAI):
- Base URL: https://{location}-aiplatform.googleapis.com/v1beta1
- Reference: ruby_llm/lib/ruby_llm/providers/vertexai/
  pi/packages/ai/src/providers/google-vertex.ts

**AWS Bedrock** (Ask::Provider::Bedrock):
- Base URL: https://bedrock-runtime.{region}.amazonaws.com
- Reference: ruby_llm/lib/ruby_llm/providers/bedrock/
  pi/packages/ai/src/providers/amazon-bedrock.ts

**Mistral** (Ask::Provider::Mistral):
- Base URL: https://api.mistral.ai/v1
- Reference: ruby_llm/lib/ruby_llm/providers/mistral/

**Cloudflare Workers AI + AI Gateway** (Ask::Provider::Cloudflare):
- Workers AI: https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/v1
- AI Gateway (OpenAI compat): https://gateway.ai.cloudflare.com/v1/{ACCOUNT_ID}/{GATEWAY_ID}/openai
- AI Gateway (Anthropic compat): https://gateway.ai.cloudflare.com/v1/{ACCOUNT_ID}/{GATEWAY_ID}/anthropic
- Reference: pi/packages/ai/src/providers/cloudflare.ts (the canonical implementation)

**Ollama** (Ask::Provider::Ollama):
- Base URL: http://localhost:11434 (default, configurable)
- Reference: ruby_llm/lib/ruby_llm/providers/ollama/

### 3. OAuth Infrastructure

Used for multi-user auth flows. The endpoints are standard OAuth 2.0.

| Provider | Authorize URL | Token URL |
|---|---|---|
| OpenAI | https://auth.openai.com/oauth/authorize | https://auth.openai.com/oauth/token |
| Anthropic | https://claude.ai/oauth/authorize | https://platform.claude.com/v1/oauth/token |
| GitHub | https://github.com/login/oauth/authorize | https://github.com/login/oauth/access_token |
| Google | https://accounts.google.com/o/oauth2/v2/auth | https://oauth2.googleapis.com/token |

**How we use them:** Ask::Auth::OAuth reads these URLs from configuration, performs
the PKCE flow, and stores the result in the configured storage provider (env var,
file, or database). We do NOT implement OAuth infrastructure — we call the standard
endpoints.

**Reference:** pi/packages/ai/src/providers/simple-options.ts (OAuth config)
  pi/packages/ai/src/providers/github-copilot-headers.ts (Copilot OAuth)

### 4. GitHub Copilot API

- **Endpoints:**
  - Chat: https://api.individual.githubcopilot.com
  - Enterprise: https://copilot-api.{enterprise-domain}
  - Token: https://api.{domain}/copilot_internal/v2/token
- **Reference:** pi/packages/ai/src/providers/github-copilot-headers.ts
- **Not currently planned but documented for future.** GitHub Copilot uses a
  custom OAuth flow with device code grant. This could be added to ask-llm-providers
  as Ask::Provider::GitHubCopilot.

### 5. Vercel AI Gateway

- **URL:** https://ai-gateway.vercel.sh
- **Purpose:** Standardized access to multiple providers through one endpoint.
  Supports OpenAI, Anthropic, Google, and more with a unified API.
- **Reference:** pi/packages/ai/src/providers/images (uses Vercel for image generation)
- **How we use it:** Any OpenAI-compatible provider can use ask-openai with
  base_url: https://ai-gateway.vercel.sh/v1. No separate implementation needed.

### What We Do NOT Build (covered by existing services)

| What | Covered by |
|---|---|
| Model catalog / pricing database | models.dev API |
| Provider wire formats | Provider gems call these directly |
| OAuth infrastructure | Standard endpoints, Ask::Auth::OAuth |
| API routing / load balancing | OpenRouter, Vercel AI Gateway |
| Model registry / discovery | models.dev + provider list endpoints |
| Pricing calculation | models.dev provides per-model pricing |
| Rate limiting | Provider APIs do this natively |

### What We DO Build (unique to ask-rb)

| What | Where |
|---|---|
| Agent loop with extension system | ask-agent |
| Rails integration with AR persistence | ask-rails |
| Service context system (ask-github, etc.) | ask-* service gems |
| Credential resolution chain | ask-auth |
| Tool framework + execution tools | ask-tools, ask-tools-shell |
| Unified provider interface with capabilities | ask-core + ask-llm-providers |
| Agent-friendly error messages | every gem |
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

## Documentation

### Documentation
- **Update ask-docs** after releasing v0.1.0 — the docs site at github.com/ask-rb/ask-docs must reflect this gems API, usage, and position in the ecosystem.
- The ask-docs repo has a Jekyll site with sections for each gem under core/, providers/, tools/, agent/.
- Add or update the relevant page(s) and submit a PR to ask-docs.
- This is not optional — ask-docs is the public face of the ecosystem.

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
### Reference Repositories (Local)
All ask-rb gem repos are available locally at /Users/kaka/Code/ask-rb/ for reference.
Do not clone from GitHub — use the local directories:
- Source code: /Users/kaka/Code/ask-rb/GEMNAME/lib/
- Tests: /Users/kaka/Code/ask-rb/GEMNAME/test/
- Goal: /Users/kaka/Code/ask-rb/GEMNAME/GOAL.md
- Gemspec: /Users/kaka/Code/ask-rb/GEMNAME/GEMNAME.gemspec

Other reference projects in the same workspace:
- /Users/kaka/Code/ask-rb/ruby_llm/ — RubyLLM gem (providers, models, streaming)
- /Users/kaka/Code/ask-rb/ruby_llm-conductor/ — Original conductor (agent loop, tools)
- /Users/kaka/Code/ask-rb/llm-proxy/ — Protocol normalization patterns
- /Users/kaka/Code/ask-rb/pi/ — Pi agent (TypeScript, provider architecture)
- /Users/kaka/Code/ask-rb/solid_agents/ — Original solid_agents (Rails engine)
- /Users/kaka/Code/ask-rb/composio/ — Composio SDK (MCP tool execution examples)
- /Users/kaka/Code/ask-rb/ask-docs/ — Documentation site (update after release)

### Testing
- Use Minitest (not RSpec) — consistent with the ask-rb ecosystem.
- Unit tests for every public method (normal path + edge cases + error cases).
- Integration tests with VCR cassettes for any gem that calls external APIs.
- Run the full suite before every commit: `bundle exec rake test`.
