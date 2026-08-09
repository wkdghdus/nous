#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "optparse"
require "pathname"
require "time"

$LOAD_PATH.unshift((Pathname(__dir__).parent + "lib").to_s)
require "nous"

ROOT = Pathname(__dir__).parent.expand_path
DEFAULT_VAULT_ROOT = ROOT + "vault"
DEFAULT_OUTPUT_RELATIVE = "04_generated/graph/nous_graph.json"

class GraphExportError < StandardError; end

Options = Struct.new(:vault_root, :output_path, keyword_init: true)

def parse_options(argv)
  options = Options.new(vault_root: DEFAULT_VAULT_ROOT)

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/export_graph.rb [--vault-root PATH] [--output PATH]"
    opts.on("--vault-root PATH", "Vault root. Defaults to ./vault.") do |path|
      options.vault_root = Pathname(path).expand_path
    end
    opts.on("--output PATH", "Output JSON path. Defaults to vault/04_generated/graph/nous_graph.json.") do |path|
      options.output_path = path
    end
    opts.on("-h", "--help", "Show this help.") do
      puts opts
      exit 0
    end
  end

  parser.parse!(argv)
  raise GraphExportError, "unexpected arguments: #{argv.join(" ")}" unless argv.empty?

  options.vault_root = options.vault_root.expand_path
  options
rescue OptionParser::ParseError => error
  raise GraphExportError, error.message
end

def resolve_output_path(options)
  return options.vault_root + DEFAULT_OUTPUT_RELATIVE if options.output_path.nil? || options.output_path.empty?

  path = Pathname(options.output_path)
  return path.expand_path if path.absolute?

  cwd_path = path.expand_path
  return cwd_path if cwd_path.dirname.exist?

  (options.vault_root + options.output_path).expand_path
end

def graph_timestamp
  value = ENV["NOUS_GRAPH_TIME"]
  return Time.now.utc.iso8601 if value.nil? || value.empty?

  Time.iso8601(value).utc.iso8601
rescue ArgumentError
  raise GraphExportError, "NOUS_GRAPH_TIME must be an ISO-8601 timestamp"
end

def write_graph(output_path, graph)
  output_path.dirname.mkpath
  temp_path = output_path.dirname + ".#{output_path.basename}.tmp-#{Process.pid}"
  temp_path.write(Nous::Graph.render(graph))
  FileUtils.mv(temp_path.to_s, output_path.to_s)
ensure
  temp_path&.delete if temp_path&.exist?
end

def run(argv)
  options = parse_options(argv)
  graph = Nous::Graph.build(vault_root: options.vault_root, generated_at: graph_timestamp)
  output_path = resolve_output_path(options)
  write_graph(output_path, graph)
  puts "graph: #{Nous.relative_or_absolute(output_path, options.vault_root)}"
end

begin
  run(ARGV)
rescue GraphExportError, Nous::Error => error
  warn "export_graph: #{error.message}"
  exit 1
end
