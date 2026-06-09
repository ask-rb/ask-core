# Releasing

## Prerequisites

- A GitHub Personal Access Token with `write:packages` and `read:packages` scopes
- The token must be configured in `~/.gem/credentials`:

```yaml
---
:github: Bearer YOUR_GITHUB_TOKEN
```

## Release Steps

1. Update `lib/ask/version.rb` with the new version number
2. Update `CHANGELOG.md` with the release notes
3. Build the gem:

```bash
gem build ask-core.gemspec
```

4. Push the gem to GitHub Packages:

```bash
gem push --key github --host https://rubygems.pkg.github.com/ask-rb ask-core-0.1.0.gem
```

5. Tag the release:

```bash
git tag -a v0.1.0 -m "Version 0.1.0"
git push origin v0.1.0
```
