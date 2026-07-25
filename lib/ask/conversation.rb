# frozen_string_literal: true

module Ask
  # A single message in a conversation. Immutable after creation.
  # Valid roles are: +:system+, +:user+, +:assistant+, +:tool+.
  class Message
    VALID_ROLES = %i[system user assistant tool].freeze

    # @return [Symbol] message role (:system, :user, :assistant, :tool)
    attr_reader :role

    # @return [String, nil] message text content. For multi-modal messages
    #   this is the concatenation of all text blocks. See {#content_blocks}
    #   for the full structured content.
    attr_reader :content

    # @return [Array<Ask::Content::Text, Ask::Content::Image, ...>, nil]
    #   structured content blocks for multi-modal messages. +nil+ when the
    #   message was created with a plain string +content:+ (backward compatible).
    attr_reader :content_blocks

    # @return [String, nil] optional participant name (for multi-agent scenarios)
    attr_reader :name

    # @return [String, nil] tool call ID this message is responding to
    attr_reader :tool_call_id

    # @return [Array<Hash>, nil] tool calls included in this message
    attr_reader :tool_calls

    # @return [Hash] arbitrary metadata attached to this message
    attr_reader :metadata

    # Create a new message.
    #
    # @param role [Symbol, String] message role
    # @param content [String, Array<Ask::Content>, nil] message text or array
    #   of content blocks. When an Array is given, each element must be one of
    #   the {Ask::Content} types. +content+ will be set to the plain text
    #   representation; use {#content_blocks} to access the structured blocks.
    # @param name [String, nil] participant name
    # @param tool_call_id [String, nil] tool call ID this message responds to
    # @param tool_calls [Array<Hash>, nil] tool call invocations
    # @param metadata [Hash] arbitrary metadata
    def initialize(role:, content: nil, name: nil, tool_call_id: nil, tool_calls: nil, metadata: {})
      @role = normalize_role!(role)
      @name = normalize_name(name)
      @tool_call_id = tool_call_id
      @tool_calls = tool_calls
      @metadata = metadata.dup.freeze

      if content.is_a?(Array)
        validate_content_blocks!(content)
        @content_blocks = content.map(&:freeze).freeze
        @content = extract_text_from_blocks(@content_blocks)
      else
        @content = content
        @content_blocks = nil
      end

      validate!
      freeze
    end

    # @return [Boolean] true if this message contains non-text content blocks
    #   (images, audio, video, or files).
    def multimodal?
      return false unless @content_blocks

      @content_blocks.any? { |b| !b.is_a?(Content::Text) && b.is_a?(Content::Block) }
    end

    # @return [Boolean] true if this message contains tool calls
    def tool_call? = @tool_calls&.any? == true

    # @return [Boolean] true if this is a tool result message
    def tool_result? = !@tool_call_id.nil?

    # @return [Boolean] true if role is :system
    def system? = @role == :system

    # @return [Boolean] true if role is :user
    def user? = @role == :user

    # @return [Boolean] true if role is :assistant
    def assistant? = @role == :assistant

    # @return [Boolean] true if role is :tool
    def tool? = @role == :tool

    # Convert to a hash suitable for provider wire format serialization.
    # For multi-modal messages, +:content+ is an array of content block hashes.
    # For plain text messages, +:content+ is a string (backward compatible).
    #
    # Each content block hash includes a +:type+ key for discrimination.
    # Providers can use these to build their wire format.
    #
    # @return [Hash]
    def to_h
      base = { role: @role }
      base[:name] = @name if @name
      base[:tool_call_id] = @tool_call_id if @tool_call_id

      if @content_blocks
        base[:content] = @content_blocks.map(&method(:serialize_content_block))
      else
        base[:content] = @content if @content
      end

      if @tool_calls
        base[:tool_calls] = @tool_calls.is_a?(Array) ? @tool_calls : @tool_calls.map do |id_val, tc|
          tc_id = if tc.respond_to?(:id)
            tc.id
          elsif tc.is_a?(Hash)
            tc[:id] || tc["id"] || id_val
          else
            id_val
          end

          tc_name = if tc.respond_to?(:name)
            tc.name
          elsif tc.is_a?(Hash)
            tc.dig(:function, :name) || tc.dig("function", "name") || tc[:name] || tc["name"] || id_val
          else
            id_val
          end

          tc_args = if tc.respond_to?(:arguments)
            tc.arguments.is_a?(String) ? tc.arguments : JSON.generate(tc.arguments)
          elsif tc.is_a?(Hash)
            raw = tc.dig(:function, :arguments) || tc.dig("function", "arguments") || tc[:arguments] || tc["arguments"] || "{}"
            raw.is_a?(String) ? raw : JSON.generate(raw)
          else
            "{}"
          end

          { id: tc_id, type: "function", function: { name: tc_name, arguments: tc_args } }
        end
      end

      base
    end

    # @return [Boolean] true if role, content/block, name, and tool metadata all match
    def ==(other)
      return false unless other.is_a?(Message)

      @role == other.role && @content == other.content &&
        @content_blocks == other.content_blocks &&
        @name == other.name && @tool_call_id == other.tool_call_id &&
        @tool_calls == other.tool_calls
    end
    alias eql? ==

    def hash
      [@role, @content, @content_blocks, @name, @tool_call_id, @tool_calls].hash
    end

    # @return [String]
    def inspect
      label = multimodal? ? "multimodal" : (@content_blocks ? "rich" : "text")
      preview = if @content_blocks
        blk = @content_blocks.find { |b| b.is_a?(Content::Text) }
        blk ? preview_text(blk.text) : label
      elsif @content
        @content.length > 57 ? "#{@content[0,57]}..." : @content
      end
      "#<Ask::Message role=#{@role.inspect} #{label} #{preview.inspect}>"
    end

    def preview_text(text)
      text.length > 57 ? "#{text[0, 57]}..." : text
    end

    private

    def serialize_content_block(block)
      block.respond_to?(:to_h) ? block.to_h : { type: "unknown", data: block.to_s }
    end

    def validate_content_blocks!(blocks)
      raise ArgumentError, "Content blocks must be an Array" unless blocks.is_a?(Array)
      raise ArgumentError, "Content blocks cannot be empty" if blocks.empty?

      blocks.each_with_index do |block, idx|
        next if block.is_a?(Content::Block)

        raise ArgumentError,
              "Invalid content block at index #{idx}: " \
              "expected an Ask::Content type (Text, Image, Audio, Video, or File), " \
              "got #{block.class}"
      end
    end

    def extract_text_from_blocks(blocks)
      texts = blocks.select { |b| b.is_a?(Content::Text) }.map(&:text)
      texts.empty? ? nil : texts.join("\n")
    end

    def normalize_role!(role)
      sym = role.to_s.downcase.to_sym
      raise InvalidRole, "Invalid role: #{role.inspect}. Valid: #{VALID_ROLES.join(', ')}" unless VALID_ROLES.include?(sym)

      sym
    end

    def normalize_name(name)
      return nil if name.nil?
      name.to_s.strip.empty? ? nil : name.to_s.strip
    end

    def validate!
      # Allow nil content for assistant messages with tool calls
    end
  end

  # Ordered collection of messages comprising a conversation with an LLM.
  # Provides role normalization, serialization helpers, and Enumerable access.
  #
  #   conv = Ask::Conversation.new
  #   conv << Ask::Message.new(role: :user, content: "Hello")
  #   conv.system("Be helpful")
  #   conv.to_a  # => [{ role: :user, content: "Hello" }, ...]
  #
  class Conversation
    include Enumerable

    # @param messages [Array<Ask::Message>] initial messages
    def initialize(messages = [])
      @messages = []
      messages.each { |m| self << m }
    end

    # Add a message by object or by attributes.
    # @param message [Ask::Message, Hash, String] message or attributes
    # @return [self]
    def <<(message)
      msg = message.is_a?(Message) ? message : build_message(message)
      @messages << msg
      self
    end
    alias add <<

    # Add a system message.
    # @param text [String, Array<Ask::Content>] message content or content blocks
    # @return [self]
    def system(text, **options)
      self << Message.new(role: :system, content: text, **options)
    end

    # Add a user message.
    # @param text [String, Array<Ask::Content>] message content or content blocks.
    #   Pass an Array of {Ask::Content} objects for multi-modal messages.
    # @return [self]
    # @example Plain text
    #   conv.user("Hello")
    # @example Multi-modal
    #   conv.user([
    #     Ask::Content::Text.new("What's in this image?"),
    #     Ask::Content::Image.new(url: "https://example.com/photo.jpg", mime_type: "image/jpeg")
    #   ])
    def user(text, **options)
      self << Message.new(role: :user, content: text, **options)
    end

    # Add an assistant message.
    # @param text [String, nil] message content (nil when tool_calls are present)
    # @param tool_calls [Array<Hash>, nil] tool call invocations
    # @return [self]
    def assistant(text = nil, tool_calls: nil, **options)
      self << Message.new(role: :assistant, content: text, tool_calls: tool_calls, **options)
    end

    # Add a tool result message.
    # @param content [String] tool output
    # @param tool_call_id [String] ID of the tool call this result is for
    # @return [self]
    def tool_result(content, tool_call_id:, **options)
      self << Message.new(role: :tool, content: content, tool_call_id: tool_call_id, **options)
    end

    # @yield [Message] yields each message in order
    # @return [Enumerator] if no block given
    def each(&block)
      @messages.each(&block)
    end

    # @return [Ask::Message, Array<Ask::Message>] last message or last n messages
    def last(n = nil)
      n ? @messages.last(n) : @messages.last
    end

    # @return [Integer] number of messages
    def length = @messages.length
    alias size length

    # @return [Boolean] true if there are no messages
    def empty? = @messages.empty?

    # Remove all messages.
    # @return [self]
    def clear
      @messages.clear
      self
    end

    # Access message by index.
    # @param index [Integer] zero-based index
    # @return [Ask::Message, nil]
    def [](index)
      @messages[index]
    end

    # @return [Array<Hash>] messages as an array of hashes
    def to_a
      @messages.map(&:to_h)
    end

    # @param role [Symbol, String] role to filter by
    # @return [Array<Ask::Message>] messages with the given role
    def by_role(role)
      @messages.select { |m| m.role == role.to_sym }
    end

    # @return [Array<Ask::Message>] system messages
    def system_messages = by_role(:system)

    # @return [Array<Ask::Message>] user messages
    def user_messages = by_role(:user)

    # @return [Array<Ask::Message>] assistant messages
    def assistant_messages = by_role(:assistant)

    # @return [Array<Ask::Message>] tool messages
    def tool_messages = by_role(:tool)

    # Walk message history to find a matching assistant tool call for a tool result.
    # Returns the assistant message that contains the tool call, or nil.
    def find_matching_tool_call(tool_call_id)
      @messages.reverse.find do |m|
        next unless m.role == :assistant && m.tool_calls.is_a?(Hash)
        m.tool_calls.key?(tool_call_id)
      end
    end

    # Deep copy of this conversation.
    # @return [Ask::Conversation]
    def dup
      Conversation.new(@messages.map { |m|
        opts = { role: m.role, name: m.name, tool_call_id: m.tool_call_id,
                 tool_calls: m.tool_calls, metadata: m.metadata }
        if m.content_blocks
          opts[:content] = m.content_blocks.dup
        else
          opts[:content] = m.content
        end
        Message.new(**opts)
      })
    end

    # @return [String]
    def inspect
      "#<Ask::Conversation messages=#{@messages.length}>"
    end

    private

    def build_message(attrs)
      if attrs.is_a?(Hash)
        Message.new(**attrs)
      elsif attrs.is_a?(Array)
        Message.new(role: :user, content: attrs)
      else
        Message.new(role: :user, content: attrs.to_s)
      end
    end
  end
end
