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
    assert_equal "Done", hash[:content]
    assert_equal :success, hash[:status]
    assert_equal 3, hash[:metadata][:count]
  end

  def test_to_h_omits_nil_fields
    result = Ask::Result.success
    hash = result.to_h
    assert_nil hash[:content]
    assert_equal :success, hash[:status]
    assert_equal({}, hash[:metadata])
  end

  def test_to_s
    assert_equal "Hello", Ask::Result.success("Hello").to_s
  end

  def test_failure_without_error
    result = Ask::Result.failure("Failed")
    assert result.error?
    assert_nil result.error
  end
end
