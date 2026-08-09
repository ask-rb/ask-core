# frozen_string_literal: true

module Ask
  # Lightweight, dependency-free MIME detection and classification.
  #
  # Sniffs magic bytes for common binary formats and maps extensions for
  # text/documents; everything else falls back to
  # +application/octet-stream+. Kept deliberately small — ask-core has no
  # runtime dependencies.
  module Mime
    # Common binary signatures → MIME type. Each entry may carry an extra
    # proc that must also match (e.g. RIFF…WEBP for webp).
    MAGIC = [
      ["\x89PNG\r\n\x1a\n", "image/png"],
      ["\xFF\xD8\xFF", "image/jpeg"],
      ["GIF87a", "image/gif"],
      ["GIF89a", "image/gif"],
      ["RIFF", "image/webp", ->(bytes) { bytes[8, 4] == "WEBP" }],
      ["%PDF-", "application/pdf"],
      ["OggS", "audio/ogg"]
    ].freeze

    # Extension → MIME type.
    EXTENSIONS = {
      "txt" => "text/plain",
      "csv" => "text/csv",
      "json" => "application/json",
      "xml" => "application/xml",
      "md" => "text/markdown",
      "html" => "text/html",
      "rb" => "text/x-ruby",
      "py" => "text/x-python",
      "js" => "text/javascript",
      "ts" => "text/typescript",
      "pdf" => "application/pdf",
      "png" => "image/png",
      "jpg" => "image/jpeg",
      "jpeg" => "image/jpeg",
      "gif" => "image/gif",
      "webp" => "image/webp",
      "mp3" => "audio/mpeg",
      "wav" => "audio/wav",
      "ogg" => "audio/ogg",
      "mp4" => "video/mp4",
      "mov" => "video/quicktime",
      "webm" => "video/webm",
      "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    }.freeze

    module_function

    # Detect a MIME type from a filename and/or raw bytes.
    #
    # A known extension wins (docx/xlsx are zip containers and would
    # otherwise sniff as application/zip); magic bytes are used when the
    # extension is unknown.
    #
    # @param filename [String, nil]
    # @param bytes [String, nil]
    # @param default [String] fallback MIME type
    # @return [String]
    def detect(filename: nil, bytes: nil, default: "application/octet-stream")
      from_extension = from_extension(filename) if filename
      return from_extension if from_extension

      sniff(bytes) || default
    end

    # Sniff magic bytes. Returns a MIME type or nil.
    #
    # @param bytes [String] raw bytes
    # @return [String, nil]
    def sniff(bytes)
      return nil if bytes.nil? || bytes.empty?

      MAGIC.each do |(signature, mime, extra)|
        next unless bytes.start_with?(signature)
        next if extra && !extra.call(bytes)

        return mime
      end
      nil
    end

    # Map a filename's extension to a MIME type, or nil.
    #
    # @param filename [String, nil]
    # @return [String, nil]
    def from_extension(filename)
      extension = filename.to_s.split(".").last&.downcase
      EXTENSIONS[extension]
    end

    # Classify a MIME type into a broad category.
    #
    # @param mime_type [String, nil]
    # @return [Symbol] one of :image, :audio, :video, :pdf, :document,
    #   :text, :unknown
    def classify(mime_type)
      case mime_type.to_s
      when %r{\Aimage/} then :image
      when %r{\Aaudio/} then :audio
      when %r{\Avideo/} then :video
      when "application/pdf" then :pdf
      when %r{\Atext/}, "application/json", "application/xml",
           "application/javascript",
           "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
           "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
           "application/msword", "application/vnd.ms-excel"
        then :document
      else
        :unknown
      end
    end
  end
end
