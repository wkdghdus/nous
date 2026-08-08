#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "optparse"
require "pathname"
require "psych"
require "set"
require "time"

ROOT = Pathname(__dir__).parent.expand_path
DEFAULT_VAULT_ROOT = ROOT + "vault"
DEFAULT_OUTPUT_RELATIVE = "04_generated/graph/nous_graph.json"
SCHEMA_VERSION = "0.1"
SUMMARY_MAX_LENGTH = 240

SUPPORTED_NODE_TYPES = [
  "artifact",
  "memory",
  "value",
  "belief",
  "claim",
  "pattern",
  "project",
  "decision",
  "person",
  "question",
  "contradiction",
  "identity"
].freeze

SUPPORTED_RELATIONSHIP_TYPES = [
  "evidenced_by",
  "supports",
  "contradicts",
  "influenced_by",
  "expresses",
  "mentions",
  "changed_by",
  "part_of",
  "similar_to"
].freeze

EXCLUDED_REVIEW_STATUSES = ["rejected", "deprecated"].freeze

class GraphExportError < StandardError; end

Options = Struct.new(:vault_root, :output_path, keyword_init: true)

Record = Struct.new(:path, :relative_path, :frontmatter, :body, keyword_init: true)

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

def parse_frontmatter(path)
  text = path.read
  match = text.match(/\A---\n(.*?)\n---\n?/m)
  raise GraphExportError, "missing YAML frontmatter: #{path}" unless match

  frontmatter = Psych.safe_load(match[1], aliases: false) || {}
  raise GraphExportError, "frontmatter must be a mapping: #{path}" unless frontmatter.is_a?(Hash)

  [frontmatter, text[match[0].length..] || ""]
rescue Psych::Exception => error
  raise GraphExportError, "invalid YAML frontmatter in #{path}: #{error.message}"
end

def relative_or_absolute(path, base)
  relative = path.expand_path.relative_path_from(base.expand_path)
  relative.to_s.start_with?("..") ? path.to_s : relative.to_s
rescue ArgumentError
  path.to_s
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

def markdown_files(directory)
  return [] unless directory.directory?

  directory.children.select do |path|
    path.file? && path.extname == ".md" && path.basename.to_s != "AGENT.md"
  end
end

def reviewed_note_files(vault_root)
  notes_root = vault_root + "02_notes"
  return [] unless notes_root.directory?

  notes_root.children.select(&:directory?).flat_map { |directory| markdown_files(directory) }
end

def candidate_files(vault_root)
  reviewed_note_files(vault_root) +
    markdown_files(vault_root + "03_canonical_model/claims") +
    markdown_files(vault_root + "03_canonical_model/relationships")
end

def load_records(vault_root)
  candidate_files(vault_root).sort_by(&:to_s).map do |path|
    frontmatter, body = parse_frontmatter(path)
    Record.new(
      path: path,
      relative_path: relative_or_absolute(path, vault_root),
      frontmatter: frontmatter,
      body: body
    )
  end
end

def string_value(raw)
  raw.nil? ? "" : raw.to_s.strip
end

def excluded_record?(record)
  review_status = string_value(record.frontmatter["review_status"])
  status = string_value(record.frontmatter["status"])
  EXCLUDED_REVIEW_STATUSES.include?(review_status) || status == "archived"
end

def exportable_record?(record)
  return false if excluded_record?(record)

  review_status = string_value(record.frontmatter["review_status"])
  status = string_value(record.frontmatter["status"])
  raise GraphExportError, "missing review_status: #{record.relative_path}" if review_status.empty?
  raise GraphExportError, "missing status: #{record.relative_path}" if status.empty?

  review_status == "reviewed"
end

def first_h1(body)
  body.each_line do |line|
    match = line.match(/\A#\s+(.+?)\s*\z/)
    return match[1].strip unless match.nil? || match[1].strip.empty?
  end

  nil
end

def label_for(record, id)
  title = string_value(record.frontmatter["title"])
  first_h1(record.body) || (title.empty? ? id : title)
end

def summary_for(body)
  line = body.each_line.map(&:strip).find { |value| !value.empty? && !value.start_with?("#") }
  return nil if line.nil? || line.empty?

  line[0, SUMMARY_MAX_LENGTH]
end

def normalize_evidence(frontmatter)
  evidence = frontmatter["evidence"]
  return [] unless evidence.is_a?(Array)

  seen = {}
  evidence.each_with_object([]) do |entry, refs|
    next unless entry.is_a?(Hash)

    id = string_value(entry["id"])
    path = string_value(entry["path"])
    next if id.empty? || path.empty?

    key = [id, path]
    next if seen[key]

    seen[key] = true
    refs << { "id" => id, "path" => path }
  end
end

def confidence_value(record)
  raw = record.frontmatter["confidence"]
  return nil if raw.nil? || raw == ""

  value = Float(raw)
  raise GraphExportError, "confidence must be between 0 and 1: #{record.relative_path}" unless value >= 0 && value <= 1

  value
rescue ArgumentError, TypeError
  raise GraphExportError, "confidence must be numeric: #{record.relative_path}"
end

def require_field(record, field)
  value = string_value(record.frontmatter[field])
  raise GraphExportError, "missing #{field}: #{record.relative_path}" if value.empty?

  value
end

def relationship_record?(record)
  string_value(record.frontmatter["type"]) == "relationship"
end

def node_from(record)
  id = require_field(record, "id")
  type = require_field(record, "type")
  unless SUPPORTED_NODE_TYPES.include?(type)
    raise GraphExportError, "unsupported node type #{type.inspect}: #{record.relative_path}"
  end

  node = {
    "id" => id,
    "type" => type,
    "label" => label_for(record, id),
    "review_status" => "reviewed",
    "evidence" => normalize_evidence(record.frontmatter)
  }
  confidence = confidence_value(record)
  node["confidence"] = confidence unless confidence.nil?
  summary = summary_for(record.body)
  node["summary"] = summary unless summary.nil? || summary.empty?
  node["source_path"] = record.relative_path
  node
end

def relationship_data(record)
  relationship = record.frontmatter["relationship"]
  raise GraphExportError, "missing relationship mapping: #{record.relative_path}" unless relationship.is_a?(Hash)

  relationship
end

def relationship_field(record, relationship, field)
  value = string_value(relationship[field])
  raise GraphExportError, "missing relationship.#{field}: #{record.relative_path}" if value.empty?

  value
end

def edge_from(record)
  type = require_field(record, "type")
  raise GraphExportError, "unsupported edge record type #{type.inspect}: #{record.relative_path}" unless type == "relationship"

  relationship = relationship_data(record)
  relationship_type = relationship_field(record, relationship, "type")
  unless SUPPORTED_RELATIONSHIP_TYPES.include?(relationship_type)
    raise GraphExportError, "unsupported relationship type #{relationship_type.inspect}: #{record.relative_path}"
  end

  edge = {
    "id" => require_field(record, "id"),
    "from" => relationship_field(record, relationship, "from"),
    "to" => relationship_field(record, relationship, "to"),
    "relationship" => relationship_type,
    "review_status" => "reviewed",
    "evidence" => normalize_evidence(record.frontmatter)
  }
  confidence = confidence_value(record)
  edge["confidence"] = confidence unless confidence.nil?
  edge
end

def reject_unexpected_directory_type!(record)
  if relationship_record?(record) && !record.relative_path.start_with?("03_canonical_model/relationships/")
    raise GraphExportError, "relationship export records must be canonical relationships: #{record.relative_path}"
  end

  if record.relative_path.start_with?("03_canonical_model/relationships/") && !relationship_record?(record)
    raise GraphExportError, "relationship export record must have type relationship: #{record.relative_path}"
  end

  return unless record.relative_path.start_with?("03_canonical_model/claims/")
  return if string_value(record.frontmatter["type"]) == "claim"

  raise GraphExportError, "claim export record must have type claim: #{record.relative_path}"
end

def ensure_unique!(records, kind)
  seen = {}
  records.each do |record|
    id = record.fetch("id")
    if seen.key?(id)
      raise GraphExportError, "duplicate #{kind} id #{id.inspect}: #{seen.fetch(id)} and #{record.fetch("_source_path")}"
    end

    seen[id] = record.fetch("_source_path")
  end
end

def without_internal_fields(records)
  records.map { |record| record.reject { |key, _value| key.start_with?("_") } }
end

def validate_edge_endpoints!(edges, node_ids)
  edges.each do |edge|
    missing = [edge.fetch("from"), edge.fetch("to")].reject { |id| node_ids.include?(id) }
    next if missing.empty?

    raise GraphExportError, "dangling edge #{edge.fetch("id").inspect}: missing node id #{missing.join(", ")}"
  end
end

def build_graph(vault_root)
  nodes = []
  edges = []
  load_records(vault_root).each do |record|
    next unless exportable_record?(record)

    reject_unexpected_directory_type!(record)
    if relationship_record?(record)
      edges << edge_from(record).merge("_source_path" => record.relative_path)
    else
      nodes << node_from(record).merge("_source_path" => record.relative_path)
    end
  end

  ensure_unique!(nodes, "node")
  ensure_unique!(edges, "edge")
  nodes = nodes.sort_by { |node| node.fetch("id") }
  edges = edges.sort_by { |edge| edge.fetch("id") }
  validate_edge_endpoints!(edges, Set.new(nodes.map { |node| node.fetch("id") }))

  {
    "schema_version" => SCHEMA_VERSION,
    "generated_at" => graph_timestamp,
    "nodes" => without_internal_fields(nodes),
    "edges" => without_internal_fields(edges)
  }
end

def write_graph(output_path, graph)
  output_path.dirname.mkpath
  temp_path = output_path.dirname + ".#{output_path.basename}.tmp-#{Process.pid}"
  temp_path.write("#{JSON.pretty_generate(graph)}\n")
  FileUtils.mv(temp_path.to_s, output_path.to_s)
ensure
  temp_path&.delete if temp_path&.exist?
end

def run(argv)
  options = parse_options(argv)
  graph = build_graph(options.vault_root)
  output_path = resolve_output_path(options)
  write_graph(output_path, graph)
  puts "graph: #{relative_or_absolute(output_path, options.vault_root)}"
end

begin
  run(ARGV)
rescue GraphExportError => error
  warn "export_graph: #{error.message}"
  exit 1
end
