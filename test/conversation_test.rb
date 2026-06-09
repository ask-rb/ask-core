# frozen_string_literal: true

require_relative "test_helper"

class ConversationTest < Minitest::Test
  def test_create_conversation
    conv = Ask::Conversation.new
    assert_equal 0, conv.length
    assert conv.empty?
  end

  def test_add_message
    conv = Ask::Conversation.new
    conv << Ask::Message.new(role: :user, content: "Hello")
    assert_equal 1, conv.length
  end

  def test_add_message_via_hash
    conv = Ask::Conversation.new
    conv << Ask::Message.new(role: :user, content: "Hello")
    assert_equal 1, conv.length
  end

  def test_system_convenience
    conv = Ask::Conversation.new
    conv.system("You are helpful")
    assert_equal 1, conv.length
    assert conv[0].system?
  end

  def test_user_convenience
    conv = Ask::Conversation.new
    conv.user("Hello")
    assert conv[0].user?
    assert_equal "Hello", conv[0].content
  end

  def test_assistant_convenience
    conv = Ask::Conversation.new
    conv.assistant("Sure!")
    assert conv[0].assistant?
    assert_equal "Sure!", conv[0].content
  end

  def test_assistant_with_tool_calls
    conv = Ask::Conversation.new
    conv.assistant(tool_calls: [{ name: "get_weather", arguments: { location: "NYC" } }])
    assert conv[0].tool_call?
  end

  def test_tool_result_convenience
    conv = Ask::Conversation.new
    conv.tool_result("72°F", tool_call_id: "call_123")
    assert conv[0].tool?
    assert_equal "call_123", conv[0].tool_call_id
    assert conv[0].tool_result?
  end

  def test_from_initial_messages
    msgs = [Ask::Message.new(role: :user, content: "Hi"),
            Ask::Message.new(role: :assistant, content: "Hello!")]
    conv = Ask::Conversation.new(msgs)
    assert_equal 2, conv.length
  end

  def test_enumerable
    conv = Ask::Conversation.new
    conv << Ask::Message.new(role: :system, content: "S")
    conv << Ask::Message.new(role: :user, content: "U")
    conv << Ask::Message.new(role: :assistant, content: "A")

    assert_equal 3, conv.to_a.length
    assert_equal 3, conv.map(&:role).length
  end

  def test_by_role
    conv = Ask::Conversation.new
    conv.system("Sys")
    conv.user("User1")
    conv.user("User2")

    assert_equal 1, conv.system_messages.length
    assert_equal 2, conv.user_messages.length
    assert_equal 0, conv.assistant_messages.length
  end

  def test_last
    conv = Ask::Conversation.new
    conv.user("A")
    conv.user("B")
    assert_equal "B", conv.last.content
    assert_equal %w[A B], conv.last(2).map(&:content)
  end

  def test_clear
    conv = Ask::Conversation.new
    conv.user("Hello")
    assert_equal 1, conv.length
    conv.clear
    assert_equal 0, conv.length
  end

  def test_dup
    conv = Ask::Conversation.new
    conv.user("Hello")
    dup = conv.dup
    dup.user("World")
    assert_equal 1, conv.length
    assert_equal 2, dup.length
  end

  def test_to_a_hashes
    conv = Ask::Conversation.new
    conv.user("Hi")
    conv.assistant("Hey")
    hashes = conv.to_a
    assert_equal 2, hashes.length
    assert_equal :user, hashes[0][:role]
    assert_equal :assistant, hashes[1][:role]
  end
end

class MessageTest < Minitest::Test
  def test_basic_message
    msg = Ask::Message.new(role: :user, content: "Hello")
    assert_equal :user, msg.role
    assert_equal "Hello", msg.content
    refute msg.tool_call?
    refute msg.tool_result?
  end

  def test_system_message
    msg = Ask::Message.new(role: :system, content: "Be helpful")
    assert msg.system?
    refute msg.user?
    refute msg.assistant?
    refute msg.tool?
  end

  def test_valid_roles
    Ask::Message::VALID_ROLES.each do |role|
      msg = Ask::Message.new(role: role, content: "test")
      assert_equal role, msg.role
    end
  end

  def test_invalid_role
    assert_raises(Ask::InvalidRole) { Ask::Message.new(role: :admin, content: "test") }
  end

  def test_role_normalization
    msg = Ask::Message.new(role: "USER", content: "test")
    assert_equal :user, msg.role
  end

  def test_tool_call_message
    msg = Ask::Message.new(role: :assistant, tool_calls: [{ name: "f", arguments: {} }])
    assert msg.tool_call?
    assert msg.assistant?
    assert_nil msg.content
  end

  def test_tool_result_message
    msg = Ask::Message.new(role: :tool, content: "result", tool_call_id: "call_1")
    assert msg.tool_result?
    assert msg.tool?
    assert_equal "call_1", msg.tool_call_id
  end

  def test_to_h
    msg = Ask::Message.new(role: :user, content: "Hi")
    hash = msg.to_h
    assert_equal :user, hash[:role]
    assert_equal "Hi", hash[:content]
  end

  def test_to_h_omits_nil_fields
    msg = Ask::Message.new(role: :user, content: "Hi")
    assert_nil msg.name
    hash = msg.to_h
    assert_equal 2, hash.keys.length # only role and content
  end

  def test_equality
    a = Ask::Message.new(role: :user, content: "Hi")
    b = Ask::Message.new(role: :user, content: "Hi")
    c = Ask::Message.new(role: :user, content: "Bye")

    assert_equal a, b
    refute_equal a, c
  end

  def test_immutable
    msg = Ask::Message.new(role: :user, content: "Hi")
    assert msg.frozen?
  end

  def test_name_normalization
    msg = Ask::Message.new(role: :user, content: "Hi", name: "  John  ")
    assert_equal "John", msg.name

    msg2 = Ask::Message.new(role: :user, content: "Hi", name: "")
    assert_nil msg2.name
  end

  def test_metadata
    msg = Ask::Message.new(role: :user, content: "Hi", metadata: { foo: "bar" })
    assert_equal "bar", msg.metadata[:foo]
    assert msg.metadata.frozen?
  end

  def test_inspect
    msg = Ask::Message.new(role: :user, content: "Hello, World!")
    assert_match(/Message role=:user content="Hello/, msg.inspect)
  end
end
