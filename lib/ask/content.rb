# frozen_string_literal: true

module Ask
  # Content types for multi-modal messages.
  #
  # These are frozen value objects representing different kinds of content
  # that can appear in an {Ask::Message}. A message's {Message#content_blocks
  # content_blocks} may contain multiple content objects of different types,
  # allowing text, images, audio, video, and files to be interleaved naturally.
  #
  # All content types are frozen value objects with structural equality.
  # They carry the minimum fields needed for provider-agnostic use; each
  # provider serializes them to its own wire format.
  #
  # @example Text
  #   Ask::Content::Text.new("What's in this image?")
  #
  # @example Image from URL
  #   Ask::Content::Image.new(url: "https://example.com/photo.jpg",
  #                           mime_type: "image/jpeg")
  #
  # @example Multi-modal message
  #   msg = Ask::Message.new(role: :user, content: [
  #     Ask::Content::Text.new("What's in this image?"),
  #     Ask::Content::Image.new(url: "https://example.com/photo.jpg",
  #                             mime_type: "image/jpeg")
  #   ])
  #
  module Content
    # Base module for all content types.
    module Block
      def to_h
        raise NotImplementedError
      end

      def inspect
        "#<#{self.class.name}#{inspect_fields}>"
      end

      private

      def inspect_fields
        ""
      end
    end

    # A text block within a multi-modal message.
    class Text
      include Block

      # @return [String] the text content
      attr_reader :text

      # @param text [String] the text content
      def initialize(text)
        @text = text
        freeze
      end

      def ==(other)
        other.is_a?(Text) && @text == other.text
      end
      alias eql? ==

      def hash
        @text.hash
      end

      def to_h
        { type: "text", text: @text }
      end

      private

      def inspect_fields
        " #{@text.inspect}"
      end
    end

    # Base class for media content types (Image, Audio, Video).
    # All have optional +url+, +base64+, +mime_type+, and +file_id+ fields.
    class Media
      include Block

      # @return [String, nil] URL of the media
      attr_reader :url

      # @return [String, nil] Base64-encoded media data
      attr_reader :base64

      # @return [String, nil] MIME type
      attr_reader :mime_type

      # @return [String, nil] Provider-managed file ID
      attr_reader :file_id

      # @param url [String, nil] URL of the media
      # @param base64 [String, nil] Base64-encoded data
      # @param mime_type [String, nil] MIME type
      # @param file_id [String, nil] Provider-managed file ID
      def initialize(url: nil, base64: nil, mime_type: nil, file_id: nil)
        @url = url
        @base64 = base64
        @mime_type = mime_type
        @file_id = file_id
        freeze
      end

      def ==(other)
        other.is_a?(Media) && @url == other.url && @base64 == other.base64 &&
          @mime_type == other.mime_type && @file_id == other.file_id
      end
      alias eql? ==

      def hash
        [@url, @base64, @mime_type, @file_id].hash
      end

      def to_h
        h = { type: media_type }
        h[:url] = @url if @url
        h[:base64] = @base64 if @base64
        h[:mime_type] = @mime_type if @mime_type
        h[:file_id] = @file_id if @file_id
        h
      end

      private

      def media_type
        raise NotImplementedError
      end
    end

    # An image block within a multi-modal message.
    class Image < Media
      private

      def media_type
        "image"
      end
    end

    # An audio block within a multi-modal message.
    class Audio < Media
      private

      def media_type
        "audio"
      end
    end

    # A video block within a multi-modal message.
    class Video < Media
      private

      def media_type
        "video"
      end
    end

    # An inline file block within a multi-modal message.
    class File
      include Block

      # @return [String] the file content
      attr_reader :data

      # @return [String, nil] MIME type
      attr_reader :mime_type

      # @return [String, nil] original filename
      attr_reader :filename

      # @param data [String] the file content
      # @param mime_type [String, nil] MIME type
      # @param filename [String, nil] original filename
      def initialize(data:, mime_type: nil, filename: nil)
        @data = data
        @mime_type = mime_type
        @filename = filename
        freeze
      end

      def ==(other)
        other.is_a?(File) && @data == other.data &&
          @mime_type == other.mime_type && @filename == other.filename
      end
      alias eql? ==

      def hash
        [@data, @mime_type, @filename].hash
      end

      def to_h
        { type: "file", data: @data, mime_type: @mime_type, filename: @filename }
      end
    end
  end
end
