# frozen_string_literal: true

require "base64"

module Ask
  # A file a user attached to a message.
  #
  # Sources (exactly one per attachment):
  #   path:     local file path
  #   url:      http(s) or data: URI
  #   data:     raw bytes
  #   io:       an IO/StringIO (read at render time)
  #   blob:     a duck-typed object with +download+/+path+/+read+
  #             (e.g. an ActiveStorage blob)
  #   file_id:  a provider-managed file reference (no bytes here)
  #
  # Delivery modes:
  #   :inline (default) — the bytes are sent to the model (via the
  #     provider's serializers) so it can read the file. Provider
  #     capability gates apply.
  #   :context — only a manifest line reaches the model:
  #     "[Attached file: name (mime, N bytes)]". The model knows the file
  #     exists but never receives its content. Provider-agnostic — right
  #     for agents that must not read uploaded files (e.g. a
  #     requirements-gathering assistant).
  #
  # @example Inline image from a local path
  #   Ask::Attachment.new(path: "receipt.png")
  #
  # @example Context-only (know it exists, don't read it)
  #   Ask::Attachment.new(path: "invoice.csv", delivery: :context)
  #
  # @example ActiveStorage blob
  #   Ask::Attachment.new(blob: work_request.source_files.first)
  class Attachment
    DELIVERY_MODES = %i[inline context].freeze

    # @return [String, nil] original filename
    attr_reader :filename

    # @return [String] MIME type
    attr_reader :mime_type

    # @return [Integer, nil] size in bytes
    attr_reader :size

    # @return [Symbol] :inline or :context
    attr_reader :delivery

    # @return [String, nil] URL (http(s) or data: URI) when given
    attr_reader :url

    # @return [String, nil] provider-managed file ID when given
    attr_reader :file_id

    # @param path [String, nil] local file path
    # @param url [String, nil] http(s) or data: URI
    # @param data [String, nil] raw bytes
    # @param io [IO, StringIO, nil]
    # @param blob [Object, nil] duck-typed blob (+download+/+path+/+read+)
    # @param file_id [String, nil] provider-managed file reference
    # @param filename [String, nil] override the derived filename
    # @param mime_type [String, nil] override the derived MIME type
    # @param delivery [Symbol] :inline (default) or :context
    def initialize(path: nil, url: nil, data: nil, io: nil, blob: nil, file_id: nil,
                   filename: nil, mime_type: nil, delivery: :inline)
      sources = { path: path, url: url, data: data, io: io, blob: blob, file_id: file_id }
      given = sources.count { |_, value| !value.nil? }
      raise ArgumentError, "Provide exactly one attachment source" unless given == 1

      @delivery = delivery.to_sym
      raise ArgumentError, "Unknown delivery mode: #{delivery.inspect}" unless DELIVERY_MODES.include?(@delivery)

      @path = path
      @io = io
      @blob = blob
      @url = url
      @file_id = file_id
      @raw_data = data
      @filename = filename || derive_filename
      @mime_type = mime_type || derive_mime_type
      @size = derive_size
      freeze
    end

    # Raw bytes, when the source can provide them (path/io/data/blob/data
    # URIs). nil for URLs and provider file references — those are passed
    # to the provider as-is.
    #
    # @return [String, nil]
    def data
      return @raw_data unless @raw_data.nil?
      return nil if @file_id
      return decode_data_uri if data_uri?

      if @path
        File.binread(@path)
      elsif @io
        @io.rewind if @io.respond_to?(:rewind)
        @io.read
      elsif @blob
        if @blob.respond_to?(:download)
          @blob.download
        elsif @blob.respond_to?(:read)
          @blob.read
        end
      end
    end

    # Base64-encoded bytes, when available.
    #
    # @return [String, nil]
    def base64
      bytes = data
      bytes && Base64.strict_encode64(bytes)
    end

    # Broad category of the file (see {Mime.classify}).
    #
    # @return [Symbol]
    def type
      Mime.classify(mime_type)
    end

    # The manifest line rendered for {delivery: :context} attachments.
    #
    # @return [String]
    def manifest_line
      details = [mime_type, (size ? "#{size} bytes" : nil)].compact.join(", ")
      "[Attached file: #{filename || "file"} (#{details})]"
    end

    # Convert to the content block carried by the message.
    #
    # :context attachments become a plain {Content::Text} manifest line;
    # :inline attachments become the matching media/file block so the
    # provider serializers can send the bytes.
    #
    # @return [Content::Block]
    def to_content
      return Content::Text.new(manifest_line) if context?

      case type
      when :image
        Content::Image.new(url: url, base64: base64, mime_type: mime_type, file_id: file_id)
      when :audio
        Content::Audio.new(url: url, base64: base64, mime_type: mime_type, file_id: file_id)
      when :video
        Content::Video.new(url: url, base64: base64, mime_type: mime_type, file_id: file_id)
      else
        Content::File.new(data: data, mime_type: mime_type, filename: filename,
                          url: url, file_id: file_id)
      end
    end

    # @return [Boolean] whether only context (a manifest line) is sent
    def context?
      @delivery == :context
    end

    # @return [Boolean] whether the bytes are sent to the model
    def inline?
      @delivery == :inline
    end

    # Coerce a single value into an {Attachment}:
    #   Attachment → itself
    #   Content::Block → itself (already a block)
    #   String → treated as a local file path
    #   Hash → keyword constructor arguments
    #   duck-typed blob (+download+/+path+/+read+) → blob source
    #
    # @param value [Object]
    # @return [Attachment, Content::Block]
    def self.wrap(value)
      case value
      when Attachment, Content::Block
        value
      when String
        new(path: value)
      when Hash
        new(**value.transform_keys(&:to_sym))
      else
        if value.respond_to?(:download) || value.respond_to?(:path) || value.respond_to?(:read)
          new(blob: value)
        else
          raise ArgumentError, "Cannot use #{value.class} as an attachment"
        end
      end
    end

    # Coerce a value or array of values into an array of attachments
    # (and/or content blocks).
    #
    # @param values [Object, Array<Object>]
    # @return [Array<Attachment, Content::Block>]
    def self.wrap_all(values)
      Array(values).map { |value| wrap(value) }
    end

    private

    attr_reader :path, :io, :blob

    def derive_filename
      case
      when @path then File.basename(@path)
      when @url
        if data_uri?
          nil
        else
          File.basename(URI.parse(@url).path)
        end
      when @io
        @io.respond_to?(:path) ? File.basename(@io.path.to_s) : nil
      when @blob
        if @blob.respond_to?(:filename)
          @blob.filename.to_s
        elsif @blob.respond_to?(:name)
          @blob.name.to_s
        end
      end
    end

    def derive_mime_type
      bytes = sniffable_bytes
      Mime.detect(filename: filename, bytes: bytes)
    end

    # Bytes we can afford to sniff without reading the whole file.
    # Missing files resolve to nil (data/size raise at render time).
    def sniffable_bytes
      return @raw_data[0, 16] if @raw_data
      return nil if @file_id || url && !data_uri?

      if @path
        File.binread(@path, 16) rescue nil
      elsif @io
        data&.to_s[0, 16]
      elsif @blob
        if @blob.respond_to?(:download)
          @blob.download.to_s[0, 16]
        elsif @blob.respond_to?(:read)
          data&.to_s[0, 16]
        end
      end
    end

    def derive_size
      return @raw_data.bytesize if @raw_data
      return nil if @file_id
      return decode_data_uri.bytesize if data_uri?

      if @path
        File.size(@path) rescue nil
      elsif @blob && @blob.respond_to?(:byte_size)
        @blob.byte_size
      end
    end

    def data_uri?
      @url.to_s.start_with?("data:")
    end

    def decode_data_uri
      DataURI.decode(@url).last
    end
  end
end
