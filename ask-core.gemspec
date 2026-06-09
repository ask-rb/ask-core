require_relative "lib/ask/version"

Gem::Specification.new do |spec|
  spec.name = "ask-core"
  spec.version = Ask::VERSION
  spec.authors = ["Kaka Ruto"]
  spec.email = ["kaka@anywaye.com"]

  spec.summary = "Foundation gem for the ask-rb ecosystem"
  spec.description = "Provides Ask::Provider (abstract interface), Ask::Conversation, Ask::Stream, and model catalog. Zero dependencies."
  spec.homepage = "https://github.com/ask-rb/ask-core"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]


  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "mocha", "~> 3.1"
  spec.add_development_dependency "rake", "~> 13.0"
end
