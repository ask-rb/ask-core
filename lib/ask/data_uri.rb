# frozen_string_literal: true

require "base64"
require "uri"

module Ask
  # Build and parse data: URIs (RFC 2397).
  #
  # @example
  #   Ask::DataURI.encode("hello", mime_type: "text/plain")
  #   # => "data:text/plain;base64,aGVsbG8="
  #
  #   Ask::DataURI.decode("data:text/plain;base64,aGVsbG8=")
  #   # => ["text/plain", "hello"]
  module DataURI
    module_function

    # Encode raw bytes as a data URI.
    #
    # @param data [String] raw bytes
    # @param mime_type [String] MIME type
    # @return [String]
    def encode(data, mime_type: "application/octet-stream")
      from_base64(Base64.strict_encode64(data), mime_type: mime_type)
    end

    # Build a data URI from already-encoded base64 (e.g. content blocks
    # that carry a +base64+ field).
    #
    # @param base64 [String] base64-encoded data
    # @param mime_type [String] MIME type
    # @return [String]
    def from_base64(base64, mime_type: "application/octet-stream")
      "data:#{mime_type};base64,#{base64}"
    end

    # Parse a data URI into [mime_type, raw bytes].
    #
    # @param uri [String] a data: URI
    # @return [Array(String, String)]
    # @raise [ArgumentError] when +uri+ is not a data URI
    def decode(uri)
      match = uri.to_s.match(%r{\Adata:([^;,]*)((?:;[^,]*)*),(.*)\z}m)
      raise ArgumentError, "Not a data URI: #{uri.to_s[0, 60].inspect}..." unless match

      mime = match[1].empty? ? "text/plain" : match[1]
      params = match[2]
      payload = match[3]
      if params.include?(";base64")
        [mime, Base64.strict_decode64(payload)]
      else
        [mime, URI.decode_www_form_component(payload)]
      end
    end
  end
end
