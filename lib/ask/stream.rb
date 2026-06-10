# frozen_string_literal: true

module Ask
  # A single chunk of streaming output from an LLM provider.
  # Yielded by {Ask::Stream} during a streaming response.
  class Chunk
    # @return [String, nil] text content of this chunk
    attr_reader :content

    # @return [Array<Hash>, nil] tool call invocations in this chunk
    attr_reader :tool_calls

    # @return [String, nil] reason the stream finished ("stop", "length", "tool_calls")
    attr_reader :finish_reason

    # @return [Hash, nil] token usage metadata
    attr_reader :usage

    # @return [Hash, nil] raw response data from the provider
    attr_reader :raw

    # @return [String, nil] reasoning/thinking text from the model (e.g. chain-of-thought)
    attr_reader :thinking

    def initialize(content: nil, tool_calls: nil, finish_reason: nil, usage: nil, raw: nil, thinking: nil)
      @content = content
      @tool_calls = tool_calls
      @finish_reason = finish_reason
      @usage = usage
      @raw = raw
      @thinking = thinking
    end

    # @return [Boolean] true if this is the final chunk in a stream
    def finished? = !@finish_reason.nil?

    # @return [Boolean] true if this chunk contains tool calls
    def tool_call? = @tool_calls&.any? == true

    # @return [Boolean] true if this chunk contains thinking/reasoning content
    def thinking? = @thinking.to_s.length > 0

    # @return [String] text content as a plain string
    def to_s
      @content.to_s
    end

    # @return [String] human-readable representation
    def inspect
      "#<Ask::Chunk content=#{@content.inspect} finish_reason=#{@finish_reason.inspect}>"
    end
  end

  # Streaming response from an LLM provider. Wraps an enumerable of {Chunk}s and
  # provides accumulation into a single string or message.
  #
  #   stream = Ask::Stream.new { |chunk| puts chunk.content }
  #   stream.each { |chunk| ... }
  #   stream.accumulated_text  # => "full response text"
  #
  class Stream
    include Enumerable

    # @param chunk_handler [Proc, nil] optional callback invoked for each chunk as it arrives
    def initialize(&chunk_handler)
      @chunks = []
      @chunk_handler = chunk_handler
      @accumulated = +""
      @finished = false
    end

    # Iterate over all accumulated chunks.
    # @yield [Chunk] each chunk
    # @return [Enumerator] if no block given
    def each(&block)
      return enum_for(:each) unless block

      @chunks.each(&block)
      self
    end

    # Add a chunk to the stream.
    # @param chunk [Chunk, String] chunk to add (strings are wrapped in Chunk)
    # @return [Chunk] the added chunk
    def add(chunk)
      chunk = Chunk.new(content: chunk) if chunk.is_a?(String)

      @chunks << chunk
      @accumulated << chunk.content.to_s if chunk.content
      @chunk_handler&.call(chunk)
      chunk
    end

    # Mark the stream as finished.
    def finish!
      @finished = true
    end

    # @return [Boolean] true if the stream has been finished
    def finished? = @finished

    # @return [String] full accumulated text from all chunks
    def accumulated_text
      @accumulated.dup
    end
    alias to_s accumulated_text

    # @return [Hash] accumulated usage across all chunks, merged by key
    def accumulated_usage
      @chunks
        .map(&:usage)
        .compact
        .reduce({}) do |acc, u|
          acc.merge(u) { |_key, old, new| old + new }
        end
    end

    # @return [Array<Chunk>] a copy of all accumulated chunks
    def chunks = @chunks.dup

    # @return [Integer] number of chunks accumulated
    def length = @chunks.length

    # @return [String] human-readable representation
    def inspect
      finished = @finished ? "finished" : "streaming"
      "#<Ask::Stream #{finished} chunks=#{@chunks.length}>"
    end
  end
end
