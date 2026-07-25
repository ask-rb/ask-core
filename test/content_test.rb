# frozen_string_literal: true

require_relative "test_helper"

module Ask
  class ContentTest < Minitest::Test
    # --- Content::Text ---

    def test_text_content
      t = Content::Text.new("Hello")
      assert_equal "Hello", t.text
    end

    def test_text_content_positional
      t = Content::Text.new("Hello world")
      assert_equal "Hello world", t.text
    end

    def test_text_content_immutable
      t = Content::Text.new("Hello")
      assert t.frozen?
    end

    def test_text_equality
      assert_equal Content::Text.new("Hello"), Content::Text.new("Hello")
    end

    def test_text_inequality
      refute_equal Content::Text.new("Hello"), Content::Text.new("World")
    end

    # --- Content::Image ---

    def test_image_from_url
      img = Content::Image.new(url: "https://example.com/photo.jpg", mime_type: "image/jpeg")
      assert_equal "https://example.com/photo.jpg", img.url
      assert_equal "image/jpeg", img.mime_type
      assert_nil img.base64
      assert_nil img.file_id
    end

    def test_image_from_base64
      img = Content::Image.new(base64: "AAAAbbbbCCCC", mime_type: "image/png")
      assert_equal "AAAAbbbbCCCC", img.base64
      assert_equal "image/png", img.mime_type
      assert_nil img.url
    end

    def test_image_with_file_id
      img = Content::Image.new(file_id: "file_abc123")
      assert_equal "file_abc123", img.file_id
    end

    def test_image_immutable
      img = Content::Image.new(url: "https://example.com/img.jpg")
      assert img.frozen?
    end

    # --- Content::Audio ---

    def test_audio_from_url
      audio = Content::Audio.new(url: "https://example.com/audio.mp3", mime_type: "audio/mpeg")
      assert_equal "https://example.com/audio.mp3", audio.url
      assert_equal "audio/mpeg", audio.mime_type
    end

    def test_audio_from_base64
      audio = Content::Audio.new(base64: "data", mime_type: "audio/wav")
      assert_equal "data", audio.base64
    end

    # --- Content::Video ---

    def test_video_from_url
      video = Content::Video.new(url: "https://example.com/video.mp4", mime_type: "video/mp4")
      assert_equal "https://example.com/video.mp4", video.url
    end

    # --- Content::File ---

    def test_file_content
      file = Content::File.new(data: "file content", mime_type: "text/plain", filename: "notes.txt")
      assert_equal "file content", file.data
      assert_equal "text/plain", file.mime_type
      assert_equal "notes.txt", file.filename
    end

    def test_file_without_optional_fields
      file = Content::File.new(data: "content")
      assert_equal "content", file.data
      assert_nil file.mime_type
      assert_nil file.filename
    end

    # --- Data::Define properties ---

    def test_content_types_are_frozen_value_objects
      assert Content::Text.new("t").frozen?
      assert Content::Image.new(url: "u").frozen?
      assert Content::Audio.new(url: "a").frozen?
      assert Content::Video.new(url: "v").frozen?
      assert Content::File.new(data: "f").frozen?
    end

    def test_content_types_support_pattern_matching
      case Content::Image.new(url: "https://example.com/img.jpg")
      when Content::Image
        assert true
      else
        flunk "Pattern match failed"
      end
    end

    def test_content_types_respond_to_to_h
      assert_respond_to Content::Text.new("t"), :to_h
      assert_respond_to Content::Image.new(url: "u"), :to_h
      assert_respond_to Content::File.new(data: "f"), :to_h
    end
  end

  class MultiModalMessageTest < Minitest::Test
    # --- Creating multi-modal messages ---

    def test_create_with_content_blocks
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("What's in this image?"),
        Ask::Content::Image.new(url: "https://example.com/photo.jpg", mime_type: "image/jpeg")
      ])

      assert msg.multimodal?
      assert_equal 2, msg.content_blocks.length
      assert_kind_of Ask::Content::Text, msg.content_blocks[0]
      assert_kind_of Ask::Content::Image, msg.content_blocks[1]
    end

    def test_content_extracts_text_from_blocks
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("First line"),
        Ask::Content::Image.new(url: "https://example.com/img.jpg"),
        Ask::Content::Text.new("Second line")
      ])

      assert_includes msg.content, "First line"
      assert_includes msg.content, "Second line"
    end

    def test_content_is_nil_for_non_text_blocks
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Image.new(url: "https://example.com/img.jpg")
      ])

      assert_nil msg.content
    end

    def test_plain_text_messages_not_multimodal
      msg = Ask::Message.new(role: :user, content: "Hello")
      refute msg.multimodal?
      assert_nil msg.content_blocks
    end

    def test_empty_content_blocks_not_allowed
      assert_raises(ArgumentError) do
        Ask::Message.new(role: :user, content: [])
      end
    end

    def test_invalid_content_block_type
      assert_raises(ArgumentError) do
        Ask::Message.new(role: :user, content: ["string", Ask::Content::Text.new("valid")])
      end
    end

    def test_content_blocks_are_frozen
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("Hello"),
        Ask::Content::Image.new(url: "https://example.com/img.jpg")
      ])

      assert msg.content_blocks.frozen?
    end

    # --- Backward compatibility ---

    def test_backward_compatible_plain_text
      msg = Ask::Message.new(role: :user, content: "Hello")
      assert_equal "Hello", msg.content
      assert_nil msg.content_blocks
      refute msg.multimodal?
    end

    def test_backward_compatible_nil_content
      msg = Ask::Message.new(role: :assistant, tool_calls: [{ name: "test", arguments: {} }])
      assert_nil msg.content
      assert_nil msg.content_blocks
    end

    def test_backward_compatible_empty_string
      msg = Ask::Message.new(role: :user, content: "")
      assert_equal "", msg.content
      assert_nil msg.content_blocks
    end

    # --- to_h serialization ---

    def test_to_h_plain_text
      msg = Ask::Message.new(role: :user, content: "Hello")
      h = msg.to_h
      assert_equal "Hello", h[:content]
      assert_equal :user, h[:role]
    end

    def test_to_h_multimodal
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("What's in this?"),
        Ask::Content::Image.new(url: "https://example.com/img.jpg", mime_type: "image/jpeg")
      ])

      h = msg.to_h
      assert_kind_of Array, h[:content]
      assert_equal 2, h[:content].length

      first = h[:content][0]
      assert_equal "text", first[:type]
      assert_equal "What's in this?", first[:text]

      second = h[:content][1]
      assert_equal "image", second[:type]
      assert_equal "https://example.com/img.jpg", second[:url]
      assert_equal "image/jpeg", second[:mime_type]
    end

    def test_to_h_multimodal_image_from_base64
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Image.new(base64: "AAAA", mime_type: "image/png")
      ])

      h = msg.to_h
      img = h[:content][0]
      assert_equal "AAAA", img[:base64]
      assert_nil img[:url]
    end

    def test_to_h_multimodal_audio
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Audio.new(url: "https://example.com/sound.mp3", mime_type: "audio/mpeg")
      ])

      h = msg.to_h
      assert_equal "audio", h[:content][0][:type]
    end

    def test_to_h_multimodal_video
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Video.new(url: "https://example.com/vid.mp4", mime_type: "video/mp4")
      ])

      h = msg.to_h
      assert_equal "video", h[:content][0][:type]
    end

    def test_to_h_file
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::File.new(data: "file data", mime_type: "text/csv", filename: "data.csv")
      ])

      h = msg.to_h
      assert_equal "file", h[:content][0][:type]
      assert_equal "file data", h[:content][0][:data]
    end

    def test_to_h_preserves_other_fields
      msg = Ask::Message.new(
        role: :user,
        content: [Ask::Content::Text.new("Hello")],
        name: "test_user",
        metadata: { key: "val" }
      )

      h = msg.to_h
      assert_equal "test_user", h[:name]
      assert_equal({ key: "val" }, msg.metadata)
    end

    # --- Equality ---

    def test_equality_with_content_blocks
      msg1 = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("Hello"),
        Ask::Content::Image.new(url: "https://example.com/img.jpg")
      ])
      msg2 = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("Hello"),
        Ask::Content::Image.new(url: "https://example.com/img.jpg")
      ])

      assert_equal msg1, msg2
    end

    def test_inequality_with_different_blocks
      msg1 = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("Hello")
      ])
      msg2 = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("World")
      ])

      refute_equal msg1, msg2
    end

    def test_equality_plain_vs_multimodal
      plain = Ask::Message.new(role: :user, content: "Hello")
      multimodal = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("Hello")
      ])

      # Different internal representation
      refute_equal plain, multimodal
    end

    # --- Conversation with content blocks ---

    def test_conversation_user_with_blocks
      conv = Ask::Conversation.new
      conv.user([
        Ask::Content::Text.new("Describe this image:"),
        Ask::Content::Image.new(url: "https://example.com/img.jpg", mime_type: "image/jpeg")
      ])

      assert_equal 1, conv.length
      msg = conv[0]
      assert msg.multimodal?
      assert_equal 2, msg.content_blocks.length
    end

    def test_conversation_to_a_with_blocks
      conv = Ask::Conversation.new
      conv.system("Be helpful")
      conv.user([
        Ask::Content::Text.new("What's this?"),
        Ask::Content::Image.new(url: "https://example.com/img.jpg")
      ])

      arr = conv.to_a
      assert_equal 2, arr.length
      assert_kind_of Array, arr[1][:content]
      assert_equal "text", arr[1][:content][0][:type]
    end

    def test_conversation_dup_with_content_blocks
      conv = Ask::Conversation.new
      conv.user([
        Ask::Content::Text.new("Hello"),
        Ask::Content::Image.new(url: "https://example.com/img.jpg")
      ])

      dup = conv.dup
      assert_equal conv.length, dup.length
      assert_equal conv[0].content_blocks, dup[0].content_blocks
    end

    def test_conversation_dup_preserves_plain_text
      conv = Ask::Conversation.new
      conv.user("Hello")

      dup = conv.dup
      assert_equal "Hello", dup[0].content
      assert_nil dup[0].content_blocks
    end

    # --- Message predicates ---

    def test_multimodal_with_only_text_blocks
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("Hello"),
        Ask::Content::Text.new("World")
      ])

      refute msg.multimodal?, "Only text blocks should not be considered multimodal"
    end

    def test_multimodal_with_image
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Text.new("Hello"),
        Ask::Content::Image.new(url: "https://example.com/img.jpg")
      ])

      assert msg.multimodal?
    end

    def test_multimodal_with_audio
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Audio.new(url: "https://example.com/sound.mp3")
      ])

      assert msg.multimodal?
    end

    def test_multimodal_with_video
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::Video.new(url: "https://example.com/vid.mp4")
      ])

      assert msg.multimodal?
    end

    def test_multimodal_with_file
      msg = Ask::Message.new(role: :user, content: [
        Ask::Content::File.new(data: "content")
      ])

      assert msg.multimodal?
    end
  end
end
