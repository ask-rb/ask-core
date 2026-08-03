# frozen_string_literal: true

require_relative "test_helper"

class ResultTest < Minitest::Test
  def test_success_result
    result = Ask::Result.success("Completed")
    assert result.success?
    refute result.error?
    refute result.aborted?
    assert_equal "Completed", result.content
  end

  def test_success_without_content
    result = Ask::Result.success
    assert result.success?
    assert_nil result.content
  end

  def test_success_with_metadata
    result = Ask::Result.success("Done", metadata: { duration: 1.2 })
    assert_equal 1.2, result.metadata[:duration]
  end

  def test_failure_result
    result = Ask::Result.failure("Something broke", error: "Timeout")
    assert result.error?
    refute result.success?
    assert_equal "Something broke", result.content
    assert_equal "Timeout", result.error
  end

  def test_aborted_result
    result = Ask::Result.aborted("Cancelled")
    assert result.aborted?
    assert_equal "Cancelled", result.content
  end

  def test_blocked_result
    result = Ask::Result.blocked("Permission denied")
    assert result.blocked?
    assert_equal "Permission denied", result.content
  end

  def test_result_immutable
    result = Ask::Result.success("ok", metadata: { key: "value" })
    assert result.frozen?
    assert result.metadata.frozen?
  end

  def test_invalid_status_raises
    assert_raises(ArgumentError) { Ask::Result.new(status: :invalid) }
  end

  def test_to_h
    result = Ask::Result.success("Done", metadata: { count: 3 })
    hash = result.to_h
    assert_equal true, hash[:ok]
    assert_equal "Done", hash[:output]
    assert_nil hash[:error]
    assert_equal 3, hash[:metadata][:count]
  end

  def test_to_h_omits_nil_fields
    result = Ask::Result.success
    hash = result.to_h
    assert_equal true, hash[:ok]
    assert_nil hash[:output]
    assert_equal({}, hash[:metadata])
  end

  def test_to_s
    assert_equal "Hello", Ask::Result.success("Hello").to_s
  end

  def test_failure_without_error
    result = Ask::Result.failure("Failed")
    assert result.error?
    # The message doubles as the error, so tooling can read `result.error`.
    assert_equal "Failed", result.error
  end

  # --- tool API (shared Ask::Result union) ---

  def test_ok_factory
    result = Ask::Result.ok(data: "hello")
    assert result.ok?
    assert result.success?
    assert_equal "hello", result.output
    assert_equal "hello", result.content
    assert_nil result.error
    assert_equal({}, result.metadata)
  end

  def test_error_factory
    result = Ask::Result.error(message: "something broke")
    refute result.ok?
    assert result.error?
    assert_nil result.output
    assert_equal "something broke", result.error
    assert_equal "something broke", result.error_message
    assert_equal({}, result.metadata)
  end

  def test_ok_reader_and_error_message_alias
    assert Ask::Result.ok(data: "x").ok
    refute Ask::Result.error(message: "x").ok
    assert_nil Ask::Result.ok(data: "x").error_message
  end

  def test_tool_constructor_keywords
    result = Ask::Result.new(ok: true, output: "data", error: nil, metadata: { source: "test" })
    assert result.ok?
    assert_equal "data", result.output
    assert_equal "data", result.content
    assert_equal({ source: "test" }, result.metadata)

    failed = Ask::Result.new(ok: false, output: nil, error: "nope")
    refute failed.ok?
    assert failed.error?
    assert_equal "nope", failed.error
  end

  def test_output_is_nil_for_non_success
    assert_nil Ask::Result.aborted("Cancelled").output
    assert_nil Ask::Result.blocked("Denied").output
    assert_nil Ask::Result.failure("Failed").output
  end

  def test_tool_to_s
    assert_equal "42", Ask::Result.ok(data: 42).to_s
    assert_equal "fail", Ask::Result.error(message: "fail").to_s
  end

  def test_tool_inspect
    assert_match(/ok=true.*output=/, Ask::Result.ok(data: "test").inspect)
    assert_match(/ok=false.*error=/, Ask::Result.error(message: "fail").inspect)
  end
end
