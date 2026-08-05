# frozen_string_literal: true

module Ask
  # Standardized return value from tool execution.
  #
  # This is the single +Ask::Result+ for the whole ecosystem. It supports both
  # the foundational API (+success+/+failure+/+aborted+/+blocked+ with
  # +content+ and +status+) and the tool API (+ok+/+error+ with +ok?+,
  # +output+, and +error_message+):
  #
  #   Ask::Result.success("Data processed")
  #   Ask::Result.ok(data: "Data processed")
  #
  # Both are the same class and share the same +to_h+ shape, so a result
  # created by a provider's +embed+ or a tool's +execute+ can be inspected
  # uniformly.
  #
  # Feature gems extend this class or build on it — they never redefine it.
  # See ask-docs "Architecture & ownership" for the rule.
  class Result
    STATUSES = %i[success error aborted blocked short_circuited pending].freeze

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
      # @param error [Object, nil] the underlying error object (defaults to
      #   +message+ so `failure(msg).error` reads as the message)
      # @param metadata [Hash] additional metadata
      # @return [Ask::Result]
      def failure(message, error: nil, metadata: {})
        new(content: message, status: :error, error: error.nil? ? message : error, metadata: metadata)
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

      # Create a pending result (async tool): the work continues in the
      # background and the session completes it later via
      # +Ask::Agent::Session#complete_pending_tool+. The agent voices the
      # tool's interim message immediately and keeps talking.
      # @param message [String] interim status the model can voice
      # @param metadata [Hash] additional metadata
      # @return [Ask::Result]
      def pending(message, metadata: {})
        new(content: message, status: :pending, metadata: metadata)
      end

      # Create a successful result (tool API — alias for +success+).
      # @param data [Object] the tool's output
      # @param metadata [Hash] optional metadata
      # @return [Ask::Result]
      def ok(data:, metadata: {})
        new(content: data, status: :success, metadata: metadata)
      end

      # Create a failed result (tool API).
      # @param message [String] description of the failure
      # @param metadata [Hash] optional metadata
      # @return [Ask::Result]
      def error(message:, metadata: {})
        new(content: message, status: :error, error: message, metadata: metadata)
      end
      # @!endgroup
    end

    # @return [Object, nil] the result content (for +success+/+ok+ results,
    #   this is the payload; for +failure+ it is the error message)
    attr_reader :content

    # @return [Symbol] the status (:success, :error, :aborted, :blocked, :short_circuited)
    attr_reader :status

    # @return [Object, nil] the error message or underlying error object, if any
    attr_reader :error

    # @return [Hash] additional metadata
    attr_reader :metadata

    # Accepts both the foundational keywords (+content+, +status+) and the
    # tool keywords (+ok+, +output+). +ok:+ derives the status: +true+ means
    # +:success+, +false+ means +:error+.
    #
    # @param content [Object, nil] result content
    # @param output [Object, nil] tool output (takes precedence over +content+)
    # @param status [Symbol] result status
    # @param ok [Boolean, nil] whether the result is a success (derives status)
    # @param error [Object, nil] error message or underlying error object
    # @param metadata [Hash] additional metadata
    def initialize(content: nil, output: nil, status: :success, ok: nil, error: nil, metadata: {})
      @content = output.nil? ? content : output
      @status = if ok == true
                  :success
                elsif ok == false
                  :error
                else
                  status
                end
      @status = validate_status!(@status)
      @error = error
      @metadata = metadata.dup.freeze
      freeze
    end

    # @return [Boolean] true if status is :success
    def success? = @status == :success

    # @return [Boolean] true if the result is a success (tool API)
    def ok? = @status == :success

    # @return [Boolean] true if the result is pending (async tool running)
    def pending? = @status == :pending

    # @return [Boolean] true if the result is a success (tool API)
    def ok = @status == :success

    # @return [Boolean] true if status is :error
    def error? = @status == :error

    # @return [Boolean] true if status is :aborted
    def aborted? = @status == :aborted

    # @return [Boolean] true if status is :blocked
    def blocked? = @status == :blocked

    # @return [Object, nil] the output data when successful, nil otherwise (tool API)
    def output = @status == :success ? @content : nil

    # @return [Object, nil] the error message or underlying error object
    def error_message = @error

    # @return [String] the content as a string (for failures, the message)
    def to_s
      @content.to_s
    end

    # @return [Hash] serialized representation
    def to_h
      {
        ok: @status == :success,
        output: @status == :success ? @content : nil,
        error: @error,
        metadata: @metadata
      }
    end

    # @return [String] human-readable representation
    def inspect
      if @status == :success
        "#<Ask::Result ok=true output=#{@content.inspect}>"
      else
        "#<Ask::Result ok=false error=#{@error.inspect} status=#{@status.inspect}>"
      end
    end

    private

    def validate_status!(status)
      return status if STATUSES.include?(status)

      raise ArgumentError, "Invalid status #{status.inspect}. Valid: #{STATUSES.join(', ')}"
    end
  end
end
