# frozen_string_literal: true

module Ask
  # Configuration for a provider-defined or provider-executed tool.
  #
  # Provider tools are built-in capabilities that the LLM provider offers
  # natively — web search, file search, code execution, image generation,
  # and so on. They are not implemented by user code but by the provider
  # itself.
  #
  # @example Configuring a provider-executed web search
  #   Ask::ProviderTool.new(
  #     id: "openai.web_search",
  #     name: "web_search",
  #     description: "Search the internet",
  #     args: { search_context_size: "medium" }
  #   )
  #
  # @example Using shorthand factory methods
  #   Ask::ProviderTool.web_search(search_context_size: "high")
  #   Ask::ProviderTool.file_search(max_num_results: 10)
  class ProviderTool
    # @return [String] fully qualified tool identifier (e.g. "openai.web_search")
    attr_reader :id

    # @return [String] short tool name
    attr_reader :name

    # @return [String] human-readable description
    attr_reader :description

    # @return [Hash] provider-specific configuration arguments
    attr_reader :args

    # @return [Boolean] true if the provider handles execution on its side
    def provider_executed?
      true
    end

    # @return [Boolean] true — marks this as a provider tool for routing
    def provider_tool?
      true
    end

    def initialize(id:, name:, description: "", args: {})
      @id = id
      @name = name
      @description = description
      @args = args.dup.freeze
      freeze
    end

    class << self
      # OpenAI web search tool.
      # @param search_context_size [String, nil] "low", "medium", or "high"
      # @param user_location [Hash, nil] approximate location { type: "approximate", country: "US", ... }
      def web_search(search_context_size: nil, user_location: nil, allowed_domains: nil)
        args = {}.tap do |h|
          h[:search_context_size] = search_context_size if search_context_size
          h[:user_location] = user_location if user_location
          h[:allowed_domains] = allowed_domains if allowed_domains
        end
        new(id: "openai.web_search", name: "web_search", description: "Search the internet for current information", args: args)
      end

      # OpenAI file search tool. Requires a vector store.
      # @param vector_store_ids [Array<String>] IDs of vector stores to search
      # @param max_num_results [Integer, nil] maximum number of results
      def file_search(vector_store_ids:, max_num_results: nil)
        args = { vector_store_ids: vector_store_ids }.tap do |h|
          h[:max_num_results] = max_num_results if max_num_results
        end
        new(id: "openai.file_search", name: "file_search", description: "Search through uploaded files", args: args)
      end

      # OpenAI code interpreter tool.
      # @param file_ids [Array<String>, nil] IDs of files to make available
      def code_interpreter(file_ids: nil)
        args = file_ids ? { file_ids: file_ids } : {}
        new(id: "openai.code_interpreter", name: "code_interpreter", description: "Execute Python code in a sandboxed environment", args: args)
      end
    end

    # Equality based on id + args.
    def ==(other)
      return false unless other.is_a?(ProviderTool)
      id == other.id && args == other.args
    end
    alias eql? ==

    def hash
      [id, args].hash
    end
  end
end
