#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "time"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "nous/mcp/server"

module Nous
  module MCPAdapter
    module Entrypoint
      module_function

      def run(argv: ARGV, env: ENV)
        options = {}
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: bundle exec ruby scripts/nous_mcp_server.rb [--vault-root PATH]"
          opts.on("--vault-root PATH", "Use this Nous vault root") { |value| options[:vault_root] = value }
        end
        parser.parse!(argv)
        raise OptionParser::InvalidArgument, "unexpected arguments" unless argv.empty?

        vault_root = options[:vault_root] || env["NOUS_VAULT_ROOT"] || File.expand_path("../vault", __dir__)
        generated_at = parse_time(env["NOUS_MCP_TIME"])
        Server.run(vault_root: vault_root, generated_at: generated_at)
        0
      rescue OptionParser::ParseError => error
        warn "nous_mcp_server: NOUS_INVALID_INPUT: #{error.message}"
        2
      rescue Nous::Error => error
        warn "nous_mcp_server: #{error.code}: #{sanitize(error.message)}"
        1
      rescue ArgumentError
        warn "nous_mcp_server: NOUS_INVALID_INPUT: NOUS_MCP_TIME must be an ISO-8601 timestamp with a timezone"
        1
      rescue StandardError
        warn "nous_mcp_server: NOUS_INTERNAL_ERROR: server failed to start"
        1
      end

      def parse_time(value)
        return nil if value.nil? || value.empty?
        unless /(?:Z|[+-]\d{2}:\d{2})\z/i.match?(value)
          raise ArgumentError, "timezone required"
        end

        Time.iso8601(value).utc
      end

      def sanitize(message)
        message.to_s.gsub(/[\r\n]+/, " ").slice(0, 240)
      end
    end
  end
end

exit Nous::MCPAdapter::Entrypoint.run if $PROGRAM_NAME == __FILE__
