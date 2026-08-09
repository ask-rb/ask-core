# frozen_string_literal: true

require "test_helper"
require "stringio"

class AttachmentTest < Minitest::Test
  def test_requires_exactly_one_source
    assert_raises(ArgumentError) { Ask::Attachment.new }
    assert_raises(ArgumentError) { Ask::Attachment.new(path: "a.txt", url: "https://example.com/a.txt") }
  end

  def test_rejects_unknown_delivery_mode
    assert_raises(ArgumentError) { Ask::Attachment.new(data: "x", delivery: :sideways) }
  end

  def test_path_source_reads_file_and_derives_metadata
    Dir.mktmpdir do |dir|
      path = File.join(dir, "receipt.png")
      png_bytes = "\x89PNG\r\n\x1a\nfake-png-bytes".b
      File.binwrite(path, png_bytes)

      attachment = Ask::Attachment.new(path: path)

      assert_equal "receipt.png", attachment.filename
      assert_equal "image/png", attachment.mime_type
      assert_equal :image, attachment.type
      assert_equal File.size(path), attachment.size
      assert_equal png_bytes, attachment.data
      assert attachment.inline?
    end
  end

  def test_extension_wins_over_magic_bytes_for_zip_family
    Dir.mktmpdir do |dir|
      path = File.join(dir, "book.docx")
      File.binwrite(path, "PK\x03\x04fake-zip-content")

      attachment = Ask::Attachment.new(path: path)

      assert_equal "application/vnd.openxmlformats-officedocument.wordprocessingml.document", attachment.mime_type
      assert_equal :document, attachment.type
    end
  end

  def test_url_source_keeps_url_and_derives_filename
    attachment = Ask::Attachment.new(url: "https://example.com/invoices/jan.pdf")

    assert_equal "jan.pdf", attachment.filename
    assert_equal "application/pdf", attachment.mime_type
    assert_equal :pdf, attachment.type
    assert_nil attachment.data
    assert_equal "https://example.com/invoices/jan.pdf", attachment.url
  end

  def test_data_uri_source_decodes_bytes
    uri = Ask::DataURI.encode("invoice data", mime_type: "text/csv")
    attachment = Ask::Attachment.new(url: uri, filename: "bills.csv")

    assert_equal "text/csv", attachment.mime_type
    assert_equal "invoice data", attachment.data
    assert_equal 12, attachment.size
  end

  def test_io_source
    io = StringIO.new("raw bytes from io")
    attachment = Ask::Attachment.new(io: io, filename: "notes.txt")

    assert_equal "raw bytes from io", attachment.data
    assert_equal "text/plain", attachment.mime_type
  end

  def test_blob_source_with_download
    blob = Object.new
    def blob.download = "blob content"
    def blob.filename = "blob.csv"
    def blob.byte_size = 12

    attachment = Ask::Attachment.new(blob: blob)

    assert_equal "blob.csv", attachment.filename
    assert_equal "text/csv", attachment.mime_type
    assert_equal "blob content", attachment.data
    assert_equal 12, attachment.size
  end

  def test_file_id_source_has_no_bytes
    attachment = Ask::Attachment.new(file_id: "file-abc123", filename: "doc.pdf", mime_type: "application/pdf")

    assert_equal "file-abc123", attachment.file_id
    assert_nil attachment.data
    assert_nil attachment.base64
    assert_nil attachment.size
  end

  def test_inline_image_renders_image_block
    attachment = Ask::Attachment.new(data: "fake-image", mime_type: "image/png", filename: "photo.png")

    block = attachment.to_content

    assert_instance_of Ask::Content::Image, block
    assert_equal "image/png", block.mime_type
    assert_equal Base64.strict_encode64("fake-image"), block.base64
  end

  def test_inline_document_renders_file_block
    attachment = Ask::Attachment.new(data: "a,b\n1,2\n", mime_type: "text/csv", filename: "rows.csv")

    block = attachment.to_content

    assert_instance_of Ask::Content::File, block
    assert_equal "a,b\n1,2\n", block.data
    assert_equal "rows.csv", block.filename
    assert_equal "text/csv", block.mime_type
  end

  def test_context_delivery_renders_manifest_text_block
    attachment = Ask::Attachment.new(data: "a,b\n1,2\n", filename: "utility.csv", mime_type: "text/csv", delivery: :context)

    block = attachment.to_content

    assert_instance_of Ask::Content::Text, block
    assert_equal "[Attached file: utility.csv (text/csv, 8 bytes)]", block.text
    assert attachment.context?
  end

  def test_manifest_line_without_size
    attachment = Ask::Attachment.new(file_id: "f1", filename: "report.pdf", mime_type: "application/pdf")

    assert_equal "[Attached file: report.pdf (application/pdf)]", attachment.manifest_line
  end

  def test_wrap_coerces_values
    attachment = Ask::Attachment.new(data: "x", filename: "a.txt", mime_type: "text/plain")
    assert_same attachment, Ask::Attachment.wrap(attachment)

    wrapped = Ask::Attachment.wrap(path: "/tmp/a.txt")
    assert_instance_of Ask::Attachment, wrapped
    assert_equal "/tmp/a.txt", wrapped.instance_variable_get(:@path)

    blob = Object.new
    def blob.download = "y"
    assert_instance_of Ask::Attachment, Ask::Attachment.wrap(blob)

    assert_raises(ArgumentError) { Ask::Attachment.wrap(42) }
  end

  def test_wrap_all
    attachments = Ask::Attachment.wrap_all([{ data: "x", filename: "a.txt", mime_type: "text/plain" }, "any-path"])
    assert_equal 2, attachments.size
    assert attachments.all? { |a| a.is_a?(Ask::Attachment) }
  end
end

class MimeTest < Minitest::Test
  def test_detect_by_extension
    assert_equal "text/csv", Ask::Mime.detect(filename: "bills.csv")
    assert_equal "application/pdf", Ask::Mime.detect(filename: "doc.PDF")
  end

  def test_detect_by_magic_bytes
    assert_equal "image/png", Ask::Mime.detect(bytes: "\x89PNG\r\n\x1a\nrest")
    assert_equal "application/pdf", Ask::Mime.detect(bytes: "%PDF-1.7")
  end

  def test_extension_wins_over_bytes
    assert_equal "text/csv", Ask::Mime.detect(filename: "rows.csv", bytes: "PK\x03\x04zip")
  end

  def test_fallback
    assert_equal "application/octet-stream", Ask::Mime.detect(filename: "weird.xyz")
  end

  def test_sniff_webp
    assert_equal "image/webp", Ask::Mime.sniff("RIFF\x00\x00\x00\x00WEBPVP8 ")
    assert_nil Ask::Mime.sniff("RIFF\x00\x00\x00\x00WAVE")
  end

  def test_classify
    assert_equal :image, Ask::Mime.classify("image/jpeg")
    assert_equal :audio, Ask::Mime.classify("audio/mpeg")
    assert_equal :video, Ask::Mime.classify("video/mp4")
    assert_equal :pdf, Ask::Mime.classify("application/pdf")
    assert_equal :document, Ask::Mime.classify("text/csv")
    assert_equal :document, Ask::Mime.classify("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    assert_equal :unknown, Ask::Mime.classify("application/x-weird")
  end
end

class DataURITest < Minitest::Test
  def test_encode_and_decode_round_trip
    uri = Ask::DataURI.encode("hello world", mime_type: "text/plain")
    assert_equal "data:text/plain;base64,aGVsbG8gd29ybGQ=", uri
    assert_equal ["text/plain", "hello world"], Ask::DataURI.decode(uri)
  end

  def test_from_base64
    assert_equal "data:image/png;base64,AAAA", Ask::DataURI.from_base64("AAAA", mime_type: "image/png")
  end

  def test_decode_plain_uri
    assert_equal ["text/plain", "hi there"], Ask::DataURI.decode("data:text/plain,hi%20there")
  end

  def test_decode_rejects_non_data_uri
    assert_raises(ArgumentError) { Ask::DataURI.decode("https://example.com/x") }
  end
end

class AttachmentBlobMimeTest < Minitest::Test
  def test_blob_content_type_is_preferred
    blob = Object.new
    def blob.download = "some content"
    def blob.filename = "report"
    def blob.content_type = "application/pdf"

    attachment = Ask::Attachment.new(blob: blob)

    assert_equal "application/pdf", attachment.mime_type
    assert_equal :pdf, attachment.type
  end
end
