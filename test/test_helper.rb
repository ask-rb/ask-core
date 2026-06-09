# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
    add_filter "/vendor/"
    track_files "lib/**/*.rb"
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "ask"

require "minitest/autorun"
require "mocha/minitest"

module TestHelpers
  # Create a stub provider class for testing the Provider interface.
  def stub_provider_class(name: "TestProvider", slug: "test_provider")
    Class.new(Ask::Provider) do
      define_singleton_method(:name) { name }
      define_singleton_method(:slug) { slug }

      def api_base = "https://api.test.test/v1"
      def headers = { "Authorization" => "Bearer test-key" }
      def chat(messages, model:, **options, &block)
        Ask::Message.new(role: :assistant, content: "Echo: #{messages.last.content}")
      end
      def embed(text, model:)
        [0.1, 0.2, 0.3]
      end
      def list_models
        [Ask::ModelInfo.new(id: "test-model", provider: "test_provider")]
      end
    end
  end

  # Create a stub config object that responds to configuration keys.
  def stub_config(**attrs)
    obj = Object.new
    attrs.each do |key, value|
      obj.define_singleton_method(key) { value }
    end
    obj
  end
end
