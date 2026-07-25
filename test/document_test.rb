# frozen_string_literal: true

require_relative "test_helper"

module Ask
  class DocumentTest < Minitest::Test
    def test_creates_document_with_content
      doc = Document.new(content: "Hello world")
      assert_equal "Hello world", doc.content
      assert_equal({}, doc.metadata)
      assert_nil doc.id
    end

    def test_creates_document_with_metadata
      doc = Document.new(
        content: "Ruby history",
        metadata: { source: "wiki", page: 5 }
      )
      assert_equal "Ruby history", doc.content
      assert_equal({ source: "wiki", page: 5 }, doc.metadata)
    end

    def test_creates_document_with_id
      doc = Document.new(content: "Test", id: "doc_123")
      assert_equal "doc_123", doc.id
    end

    def test_metadata_is_frozen
      doc = Document.new(content: "Test", metadata: { key: "value" })
      assert doc.metadata.frozen?
    end

    def test_document_is_frozen
      doc = Document.new(content: "Test")
      assert doc.frozen?
    end

    def test_equality_matches_content_and_metadata
      doc1 = Document.new(content: "Hello", metadata: { page: 1 })
      doc2 = Document.new(content: "Hello", metadata: { page: 1 })
      assert_equal doc1, doc2
      assert doc1.eql?(doc2)
    end

    def test_inequality_with_different_content
      doc1 = Document.new(content: "Hello")
      doc2 = Document.new(content: "World")
      refute_equal doc1, doc2
    end

    def test_inequality_with_different_metadata
      doc1 = Document.new(content: "Hello", metadata: { page: 1 })
      doc2 = Document.new(content: "Hello", metadata: { page: 2 })
      refute_equal doc1, doc2
    end

    def test_equality_ignores_id
      doc1 = Document.new(content: "Hello", id: "a")
      doc2 = Document.new(content: "Hello", id: "b")
      assert_equal doc1, doc2
    end

    def test_hash_consistency
      doc1 = Document.new(content: "Hello", metadata: { page: 1 })
      doc2 = Document.new(content: "Hello", metadata: { page: 1 })
      assert_equal doc1.hash, doc2.hash
    end

    def test_to_h
      doc = Document.new(content: "Hello", metadata: { source: "test" }, id: "x")
      assert_equal({ content: "Hello", metadata: { source: "test" }, id: "x" }, doc.to_h)
    end

    def test_to_h_omits_nil_id
      doc = Document.new(content: "Hello")
      assert_equal({ content: "Hello", metadata: {} }, doc.to_h)
    end

    def test_to_json
      doc = Document.new(content: "Hello", metadata: { page: 1 })
      parsed = JSON.parse(doc.to_json)
      assert_equal "Hello", parsed["content"]
      assert_equal({ "page" => 1 }, parsed["metadata"])
    end

    def test_coerces_content_to_string
      doc = Document.new(content: :symbol_content)
      assert_equal "symbol_content", doc.content
    end

    def test_inspect_truncates_long_content
      doc = Document.new(content: "a" * 100)
      inspected = doc.inspect
      assert_match(/#<Ask::Document content=/, inspected)
      assert_operator inspected.length, :<, 100
    end
  end
end
