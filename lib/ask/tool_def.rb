# frozen_string_literal: true

module Ask
  # Immutable value object representing a tool (function) definition that can be
  # passed to LLM providers. Describes a callable tool's name, description, and
  # parameter schema.
  #
  #   ToolDef.new(
  #     name: "get_weather",
  #     description: "Get current weather for a location",
  #     parameters: {
  #       type: "object",
  #       properties: { location: { type: "string" } },
  #       required: ["location"]
  #     }
  #   )
  #
  class ToolDef
    class << self
      # Build a ToolDef from an object that responds to #name, #description,
      # #params_schema, and #provider_params.
      # @param tool [#name, #description, #params_schema] a tool-like object
      # @return [Ask::ToolDef]
      def from_tool(tool)
        schema = tool.params_schema
        new(
          name: tool.name,
          description: tool.description,
          parameters: schema,
          provider_params: tool.provider_params
        )
      end

      # Safely create a ToolDef, returning nil instead of raising on invalid input.
      # Calls the optional log block with the error message if creation fails.
      #
      # @yield [message] called with the error message if creation fails
      # @yieldparam message [String] the error description
      # @return [Ask::ToolDef, nil] the created ToolDef or nil on failure
      def safe_create(name:, description: "", parameters: nil, provider_params: {}, &log_block)
        new(name: name, description: description, parameters: parameters, provider_params: provider_params)
      rescue InvalidToolDefinition => e
        msg = e.message
        if log_block
          log_block.call(msg)
        else
          $stderr.puts "[ask-core] ToolDef.safe_create skipped: #{msg}"
        end
        nil
      end

    end

    # @return [String] tool name (must match /\\A[a-zA-Z_][a-zA-Z0-9_-]*\\z/)
    attr_reader :name

    # @return [String] description of what the tool does
    attr_reader :description

    # @return [Hash, nil] JSON Schema parameter definition
    attr_reader :parameters

    # @return [Hash] provider-specific parameters (e.g. concurrency limits)
    attr_reader :provider_params

    def initialize(name:, description: "", parameters: nil, provider_params: {})
      @name = validate_name!(name)
      @description = description.to_s
      @parameters = parameters
      @provider_params = provider_params.dup.freeze
      freeze
    end

    # Convert to a provider-specific format.
    # @yield [self] yields the tool def for custom formatting
    # @return [Hash] provider-ready parameters
    def to_provider_format(&block)
      return @parameters || default_parameters unless block

      block.call(self)
    end

    # Two ToolDefs are equal if they have the same name.
    # @return [Boolean]
    def ==(other)
      return false unless other.is_a?(ToolDef)

      name == other.name
    end
    alias eql? ==

    def hash
      name.hash
    end

    # @return [Hash] serialized representation
    def to_h
      {
        name: @name,
        description: @description,
        parameters: @parameters,
        provider_params: @provider_params
      }
    end

    # @return [String]
    def inspect
      "#<Ask::ToolDef name=#{@name.inspect}>"
    end

    private

    def validate_name!(name)
      raise InvalidToolDefinition, "Tool name is required" if name.nil? || name.to_s.strip.empty?

      normalized = name.to_s.strip
      unless normalized.match?(/\A[a-zA-Z_][a-zA-Z0-9_-]*\z/)
        raise InvalidToolDefinition,
              "Tool name must start with a letter or underscore and contain only " \
              "letters, numbers, hyphens, and underscores: #{normalized.inspect}"
      end
      normalized
    end

    def default_parameters
      {
        type: "object",
        properties: {},
        required: []
      }
    end
  end
end
