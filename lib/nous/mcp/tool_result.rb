# frozen_string_literal: true

require "json"
require "mcp"

module Nous
  module MCPAdapter
    module ToolResult
      module_function

      def success(value)
        MCP::Tool::Response.new(
          [{ type: "text", text: JSON.generate(value) }],
          structured_content: value
        )
      end

      def error(code:, message:)
        value = { "error" => { "code" => code, "message" => message } }
        MCP::Tool::Response.new(
          [{ type: "text", text: JSON.generate(value) }],
          error: true,
          structured_content: value
        )
      end
    end
  end
end
