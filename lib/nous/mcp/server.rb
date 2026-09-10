# frozen_string_literal: true

require "mcp"
require_relative "tools"

module Nous
  module MCPAdapter
    module Server
      PROTOCOL_VERSION = "2025-11-25"
      SERVER_NAME = "nous"
      SERVER_VERSION = "0.1.0"

      class StrictServer < MCP::Server
        def call_tool(request, **kwargs)
          response = super
          if response.is_a?(Hash) && response[:isError] && !response.key?(:structuredContent)
            raise MCP::Server::RequestHandlerError.new(
              "Invalid tool arguments",
              request,
              error_type: :invalid_params
            )
          end

          response
        end
      end

      module_function

      def build(vault_root:, generated_at:)
        root = Nous::PathGuard.validate_vault_root(vault_root)
        Nous::RecordIndex.scan(vault_root: root)
        time = if generated_at.nil?
                 nil
               else
                 Nous::CandidateValidation.generation_time!(generated_at).fetch(:iso8601)
               end
        configuration = MCP::Configuration.new(
          protocol_version: PROTOCOL_VERSION,
          validate_tool_call_arguments: true,
          validate_tool_call_results: true,
          exception_reporter: method(:report_exception)
        )

        StrictServer.new(
          name: SERVER_NAME,
          version: SERVER_VERSION,
          tools: TOOLS,
          prompts: [],
          resources: [],
          resource_templates: [],
          capabilities: { tools: {} },
          server_context: { vault_root: root, generated_at: time }.freeze,
          configuration: configuration
        )
      end

      def run(vault_root:, generated_at:)
        MCP.configure { |configuration| configuration.exception_reporter = method(:report_exception) }
        MCP::Server::Transports::StdioTransport.new(
          build(vault_root: vault_root, generated_at: generated_at)
        ).open
      end

      def report_exception(_exception, _context = nil)
        nil
      end
      private_class_method :report_exception
    end
  end
end
