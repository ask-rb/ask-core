# frozen_string_literal: true

module Ask
  # Standardized return value from tool execution. Wraps the outcome of a tool
  # call with status, content, and optional error metadata.
  #
  #   Ask::Result.success("Data processed")
  #   Ask::Result.failure("API returned 500")
  #
  class Result
    STATUSES = %i[success error aborted blocked short_circuited].freeze

    class << self
      # @!group Factory Methods

      # Create a successful result.
      # @param content [Object, nil] the result content
      # @param metadata [Hash] additional metadata
      # @return [Ask::Result]
      def success(content = nil, metadata: {})
        new(content: content, status: :success, metadata: metadata)
      end

      # Create a failure result.
      # @param message [String] the error description
      # @param error [Object, nil] the underlying error object
      # @param metadata [Hash] additional metadata
      # @return [Ask::Result]
      def failure(message, error: nil, metadata: {})
        new(content: message, status: :error, error: error, metadata: metadata)
      end

      # Create an aborted result (cancelled by sibling failure).
      # @param reason [String] the abort reason
      # @return [Ask::Result]
      def aborted(reason = "Aborted")
        new(content: reason, status: :aborted)
      end

      # Create a blocked result (prevented by a hook or guard).
      # @param reason [String] the block reason
      # @return [Ask::Result]
      def blocked(reason)
        new(content: reason, status: :blocked)
      end
      # @!endgroup
    end

    # @return [Object, nil] the result content
    attr_reader :content

    # @return [Symbol] the status (:success, :error, :aborted, :blocked, :short_circuited)
    attr_reader :status

    # @return [Object, nil] the underlying error, if any
    attr_reader :error

    # @return [Hash] additional metadata
    attr_reader :metadata

    def initialize(content: nil, status: :success, error: nil, metadata: {})
      @content = content
      @status = validate_status!(status)
      @error = error
      @metadata = metadata.dup.freeze
      freeze
    end

    # @return [Boolean] true if status is :success
    def success? = @status == :success

    # @return [Boolean] true if status is :error
    def error? = @status == :error

    # @return [Boolean] true if status is :aborted
    def aborted? = @status == :aborted

    # @return [Boolean] true if status is :blocked
    def blocked? = @status == :blocked

    # @return [String] the content as a string
    def to_s
      @content.to_s
    end

    # @return [Hash] serialized representation
    def to_h
      {
        content: @content,
        status: @status,
        error: @error,
        metadata: @metadata
      }.compact
    end

    # @return [String] human-readable representation
    def inspect
      "#<Ask::Result status=#{@status.inspect} content=#{@content.inspect}>"
    end

    private

    def validate_status!(status)
      return status if STATUSES.include?(status)

      raise ArgumentError, "Invalid status #{status.inspect}. Valid: #{STATUSES.join(', ')}"
    end
  end
end
