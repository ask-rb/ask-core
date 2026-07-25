# frozen_string_literal: true

module Ask
  # A piece of text content with associated metadata.
  #
  # Document is the universal value object for the RAG pipeline. It flows
  # through every stage: loaded from files by {Ask::Loader::Base loaders},
  # split into smaller pieces by {Ask::TextSplitter::Base splitters},
  # embedded and stored by vector stores, and returned by retrieval queries.
  #
  # Immutable after creation. Two documents are equal when their content and
  # metadata match.
  #
  # @example
  #   doc = Ask::Document.new(
  #     content: "Ruby was created by Matz in 1995.",
  #     metadata: { source: "history.pdf", page: 3 }
  #   )
  #   doc.content   # => "Ruby was created by Matz in 1995."
  #   doc.metadata  # => { source: "history.pdf", page: 3 }
  #   doc.id        # => nil
  #
  class Document
    # @return [String] the text content of this document
    attr_reader :content

    # @return [Hash] arbitrary metadata (source, page, chunk index, etc.)
    attr_reader :metadata

    # @return [String, nil] optional unique identifier
    attr_reader :id

    # @param content [String] the text content
    # @param metadata [Hash] arbitrary metadata (default: {})
    # @param id [String, nil] optional identifier
    def initialize(content:, metadata: {}, id: nil)
      @content = content.to_s
      @metadata = metadata.dup.freeze
      @id = id
      freeze
    end

    # @return [Hash] serializable representation
    def to_h
      { content: @content, metadata: @metadata, id: @id }.compact
    end

    # @return [String] JSON representation
    def to_json(*args)
      to_h.to_json(*args)
    end

    # Two documents are equal if their content and metadata match.
    def ==(other)
      return false unless other.is_a?(Document)

      @content == other.content && @metadata == other.metadata
    end
    alias eql? ==

    def hash
      [@content, @metadata].hash
    end

    # @return [String]
    def inspect
      preview = @content.length > 60 ? "#{@content[0, 60]}..." : @content
      "#<Ask::Document content=#{preview.inspect}>"
    end
  end
end
