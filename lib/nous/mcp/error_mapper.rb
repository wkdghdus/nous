# frozen_string_literal: true

module Nous
  module MCPAdapter
    module ErrorMapper
      MESSAGE_MAX_LENGTH = 500
      CONTROL_CHARACTERS = /[\u0000-\u001f\u007f-\u009f]/

      module_function

      def call
        ToolResult.success(yield)
      rescue Nous::Error => error
        ToolResult.error(code: sanitize(error.code, fallback: "NOUS_ERROR"), message: sanitize(error.message))
      end

      def sanitize(value, fallback: "Request could not be completed")
        text = value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        text = text.gsub(CONTROL_CHARACTERS, " ").gsub(/\s+/, " ").strip
        text = fallback if text.empty?
        text.each_char.first(MESSAGE_MAX_LENGTH).join
      end
      private_class_method :sanitize
    end
  end
end
