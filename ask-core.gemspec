require_relative "lib/ask/version"

Gem::Specification.new do |spec|
  spec.name = "ask-core"
  spec.version = Ask::VERSION
  spec.authors = ["Kaka Ruto"]
  spec.email = ["kaka@myrrlabs.com"]

  spec.summary = "Foundation gem for the ask-rb ecosystem"
  spec.description = "Provides Ask::Provider (abstract interface), Ask::Conversation, Ask::Stream, Ask::ModelCatalog, Ask::ToolDef, Ask::Result, and structured error types. Zero runtime dependencies."
  spec.homepage = "https://github.com/ask-rb/ask-core"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "mocha", "~> 3.1"
  spec.add_development_dependency "rake", "~> 13.0"
end
