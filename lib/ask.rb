# frozen_string_literal: true

require_relative "ask/version"

# Main namespace for the ask-rb ecosystem.
#
# Ask::Provider is the abstract base class for LLM providers.
# Ask::Conversation is a message container with role normalization.
# Ask::Stream provides streaming primitives for incremental responses.
# Ask::ModelCatalog resolves model names to provider metadata.
# Ask::ToolDef is an immutable tool definition struct.
# Ask::Result standardizes tool execution return values.
# Ask::Error provides structured error types.
module Ask
end

require_relative "ask/errors"
require_relative "ask/tool_def"
require_relative "ask/result"
require_relative "ask/stream"
require_relative "ask/conversation"
require_relative "ask/provider"
require_relative "ask/models"
require_relative "ask/state"
