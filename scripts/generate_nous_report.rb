#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "optparse"
require "pathname"
require "psych"
require "set"
require "time"

ROOT = Pathname(__dir__).parent.expand_path
DEFAULT_VAULT_ROOT = ROOT + "vault"
DEFAULT_OUTPUT_RELATIVE = "04_generated/reports/nous.md"
SCHEMA_VERSION = "0.1"
EXCERPT_MAX_LENGTH = 240

SECTION_DEFINITIONS = [
  ["Core Values", "values", "value"],
  ["Beliefs", "beliefs", "belief"],
  ["Patterns", "patterns", "pattern"],
  ["Memories", "memories", "memory"],
  ["Contradictions", "contradictions", "contradiction"],
  ["Questions", "questions", "question"]
].freeze

SUPPORTED_NOTE_DIRECTORIES = SECTION_DEFINITIONS.map { |_title, directory, _type| directory }.freeze
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

class NousReportError < StandardError; end

Options = Struct.new(:vault_root, :output_path, keyword_init: true)
Record = Struct.new(:relative_path, :frontmatter, :body, :record_kind, keyword_init: true)
ReportEntry = Struct.new(
  :id,
  :type,
  :label,
  :source_path,
  :confidence,
  :excerpt,
  :evidence,
  :created,
  keyword_init: true
)
Relationship = Struct.new(:id, :from, :to, :type, :confidence, :source_path, keyword_init: true)

def parse_options(argv)
  options = Options.new(vault_root: DEFAULT_VAULT_ROOT)

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/generate_nous_report.rb [--vault-root PATH] [--output PATH]"
    opts.on("--vault-root PATH", "Vault root. Defaults to ./vault.") do |path|
      options.vault_root = Pathname(path).expand_path
    end
    opts.on("--output PATH", "Output Markdown path. Defaults to vault/04_generated/reports/nous.md.") do |path|
      options.output_path = path
    end
    opts.on("-h", "--help", "Show this help.") do
      puts opts
      exit 0
    end
  end

  parser.parse!(argv)
  raise NousReportError, "unexpected arguments: #{argv.join(" ")}" unless argv.empty?

  options.vault_root = options.vault_root.expand_path
  options
rescue OptionParser::ParseError => error
  raise NousReportError, error.message
end

def parse_frontmatter(path)
  text = path.read
  match = text.match(/\A---\n(.*?)\n---\n?/m)
  raise NousReportError, "missing YAML frontmatter: #{path}" unless match

  frontmatter = Psych.safe_load(match[1], permitted_classes: [Date, Time], aliases: false) || {}
  raise NousReportError, "frontmatter must be a mapping: #{path}" unless frontmatter.is_a?(Hash)

  [frontmatter, text[match[0].length..] || ""]
rescue Psych::Exception => error
  raise NousReportError, "invalid YAML frontmatter in #{path}: #{error.message}"
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

def report_timestamp
  value = ENV["NOUS_REPORT_TIME"]
  return Time.now.utc.iso8601 if value.nil? || value.empty?

  Time.iso8601(value).utc.iso8601
rescue ArgumentError
  raise NousReportError, "NOUS_REPORT_TIME must be an ISO-8601 timestamp"
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

def record_kind_for(relative_path)
  return "claim" if relative_path.start_with?("03_canonical_model/claims/")
  return "relationship" if relative_path.start_with?("03_canonical_model/relationships/")

  "note"
end

def load_records(vault_root)
  candidate_files(vault_root).sort_by(&:to_s).map do |path|
    frontmatter, body = parse_frontmatter(path)
    relative_path = relative_or_absolute(path, vault_root)
    Record.new(
      relative_path: relative_path,
      frontmatter: frontmatter,
      body: body,
      record_kind: record_kind_for(relative_path)
    )
  end
end

def string_value(raw)
  raw.nil? ? "" : raw.to_s.strip
end

def require_field(record, field)
  value = string_value(record.frontmatter[field])
  raise NousReportError, "missing #{field}: #{record.relative_path}" if value.empty?

  value
end

def excluded_record?(record)
  review_status = string_value(record.frontmatter["review_status"])
  status = string_value(record.frontmatter["status"])
  EXCLUDED_REVIEW_STATUSES.include?(review_status) || status == "archived"
end

def exportable_record?(record)
  return false if excluded_record?(record)

  review_status = require_field(record, "review_status")
  status = require_field(record, "status")

  review_status == "reviewed" && status != "archived"
end

def note_directory(record)
  parts = record.relative_path.split("/")
  return nil unless parts[0] == "02_notes"

  parts[1]
end

def supported_note_record?(record)
  record.record_kind == "note" && SUPPORTED_NOTE_DIRECTORIES.include?(note_directory(record))
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

def excerpt_for(body)
  line = body.each_line.map(&:strip).find { |value| !value.empty? && !value.start_with?("#") }
  return nil if line.nil? || line.empty?

  line[0, EXCERPT_MAX_LENGTH]
end

def normalize_evidence(frontmatter)
  evidence = frontmatter["evidence"]
  return [] if evidence.nil?
  return [normalize_evidence_entry(evidence)].compact unless evidence.is_a?(Array)

  seen = {}
  evidence.each_with_object([]) do |entry, refs|
    normalized = normalize_evidence_entry(entry)
    next if normalized.nil?

    key = [normalized.fetch("id"), normalized.fetch("path")]
    next if seen[key]

    seen[key] = true
    refs << normalized
  end
end

def normalize_evidence_entry(entry)
  if entry.is_a?(Hash)
    id = string_value(entry["id"])
    path = string_value(entry["path"])
    return nil if id.empty? || path.empty?
  else
    id = ""
    path = string_value(entry)
  end
  return nil if id.empty? && path.empty?

  { "id" => id, "path" => path.empty? ? id : path }
end

def confidence_value(record)
  raw = record.frontmatter["confidence"]
  return nil if raw.nil? || raw == ""

  value = Float(raw)
  raise NousReportError, "confidence must be between 0 and 1: #{record.relative_path}" unless value >= 0 && value <= 1

  value
rescue ArgumentError, TypeError
  raise NousReportError, "confidence must be numeric: #{record.relative_path}"
end

def created_value(record)
  string_value(record.frontmatter["created"])
end

def sort_entries(entries)
  entries.sort_by { |entry| [entry.created.empty? ? "9999-99-99" : entry.created, entry.id] }
end

def report_entry_from(record, expected_type: nil)
  id = require_field(record, "id")
  type = require_field(record, "type")
  if expected_type && type != expected_type
    raise NousReportError, "expected type #{expected_type.inspect}, got #{type.inspect}: #{record.relative_path}"
  end

  ReportEntry.new(
    id: id,
    type: type,
    label: label_for(record, id),
    source_path: record.relative_path,
    confidence: confidence_value(record),
    excerpt: excerpt_for(record.body),
    evidence: normalize_evidence(record.frontmatter),
    created: created_value(record)
  )
end

def claim_entry_from(record)
  type = require_field(record, "type")
  raise NousReportError, "claim report record must have type claim: #{record.relative_path}" unless type == "claim"

  report_entry_from(record, expected_type: "claim")
end

def relationship_mapping(record)
  relationship = record.frontmatter["relationship"]
  raise NousReportError, "missing relationship mapping: #{record.relative_path}" unless relationship.is_a?(Hash)

  relationship
end

def relationship_field(record, relationship, field)
  value = string_value(relationship[field])
  raise NousReportError, "missing relationship.#{field}: #{record.relative_path}" if value.empty?

  value
end

def relationship_from(record)
  type = require_field(record, "type")
  raise NousReportError, "relationship report record must have type relationship: #{record.relative_path}" unless type == "relationship"

  relationship = relationship_mapping(record)
  relationship_type = relationship_field(record, relationship, "type")
  unless SUPPORTED_RELATIONSHIP_TYPES.include?(relationship_type)
    raise NousReportError, "unsupported relationship type #{relationship_type.inspect}: #{record.relative_path}"
  end

  Relationship.new(
    id: require_field(record, "id"),
    from: relationship_field(record, relationship, "from"),
    to: relationship_field(record, relationship, "to"),
    type: relationship_type,
    confidence: confidence_value(record),
    source_path: record.relative_path
  )
end

def ensure_unique_entries!(entries)
  seen = {}
  entries.each do |entry|
    if seen.key?(entry.id)
      raise NousReportError, "duplicate record id #{entry.id.inspect}: #{seen.fetch(entry.id)} and #{entry.source_path}"
    end

    seen[entry.id] = entry.source_path
  end
end

def build_report(vault_root)
  sections = SECTION_DEFINITIONS.to_h { |title, _directory, _type| [title, []] }
  claims = []
  relationships = []

  load_records(vault_root).each do |record|
    next if record.record_kind == "note" && !supported_note_record?(record)
    next unless exportable_record?(record)

    case record.record_kind
    when "note"
      title, _directory, expected_type = SECTION_DEFINITIONS.find { |_section_title, directory, _type| directory == note_directory(record) }
      entry = report_entry_from(record, expected_type: expected_type)
      sections.fetch(title) << entry
    when "claim"
      claims << claim_entry_from(record)
    when "relationship"
      relationships << relationship_from(record)
    end
  end

  entries = sections.values.flatten + claims
  ensure_unique_entries!(entries)
  entry_ids = entries.map(&:id).to_set
  relationships = relationships.select { |relationship| entry_ids.include?(relationship.from) && entry_ids.include?(relationship.to) }
  ensure_unique_relationships!(relationships)

  {
    generated_at: report_timestamp,
    sections: sections.transform_values { |entries_for_section| sort_entries(entries_for_section) },
    claims: sort_entries(claims),
    relationships: relationships.sort_by { |relationship| relationship.id }
  }
end

def ensure_unique_relationships!(relationships)
  seen = {}
  relationships.each do |relationship|
    if seen.key?(relationship.id)
      raise NousReportError, "duplicate relationship id #{relationship.id.inspect}: #{seen.fetch(relationship.id)} and #{relationship.source_path}"
    end

    seen[relationship.id] = relationship.source_path
  end
end

def relationships_by_entry(relationships)
  relationships.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |relationship, grouped|
    grouped[relationship.from] << relationship
    grouped[relationship.to] << relationship
  end
end

def escape_markdown(text)
  text.to_s.gsub("|", "\\|")
end

def evidence_text(evidence)
  evidence.map do |ref|
    id = ref.fetch("id")
    path = ref.fetch("path")
    id.empty? ? path : "#{id} (#{path})"
  end.join(", ")
end

def related_record_text(relationship, entry_id, labels_by_id)
  other_id = relationship.from == entry_id ? relationship.to : relationship.from
  direction = relationship.from == entry_id ? "to" : "from"
  label = labels_by_id.fetch(other_id, other_id)
  confidence = relationship.confidence.nil? ? "" : "; confidence: #{relationship.confidence}"
  "#{relationship.type} #{direction} #{other_id} - #{label} (source: #{relationship.source_path}#{confidence})"
end

def render_entry(entry, related, labels_by_id)
  lines = []
  lines << "- **#{escape_markdown(entry.label)}** (`#{entry.id}`)"
  lines << "  - Type: #{entry.type}"
  lines << "  - Source: #{entry.source_path}"
  lines << "  - Confidence: #{entry.confidence}" unless entry.confidence.nil?
  lines << "  - Excerpt: #{escape_markdown(entry.excerpt)}" unless entry.excerpt.nil? || entry.excerpt.empty?
  lines << "  - Evidence: #{evidence_text(entry.evidence)}" unless entry.evidence.empty?

  related_entries = related.fetch(entry.id, []).sort_by(&:id)
  unless related_entries.empty?
    lines << "  - Related records:"
    related_entries.each do |relationship|
      lines << "    - #{related_record_text(relationship, entry.id, labels_by_id)}"
    end
  end

  lines
end

def render_section(lines, title, entries, related, labels_by_id)
  lines << "## #{title}"
  lines << ""
  if entries.empty?
    lines << "No reviewed records found."
  else
    entries.each do |entry|
      lines.concat(render_entry(entry, related, labels_by_id))
    end
  end
  lines << ""
end

def render_report(report)
  entries = report.fetch(:sections).values.flatten + report.fetch(:claims)
  labels_by_id = entries.to_h { |entry| [entry.id, entry.label] }
  related = relationships_by_entry(report.fetch(:relationships))

  lines = [
    "# Nous Report",
    "",
    "Generated at: #{report.fetch(:generated_at)}",
    "Schema version: #{SCHEMA_VERSION}",
    "",
    "This report is generated from reviewed notes and reviewed canonical records only. It is source-backed and does not add new interpretation beyond accepted records.",
    ""
  ]

  report.fetch(:sections).each do |title, section_entries|
    render_section(lines, title, section_entries, related, labels_by_id)
  end

  render_section(lines, "Source-Backed Claims", report.fetch(:claims), related, labels_by_id)
  "#{lines.join("\n").rstrip}\n"
end

def write_report(output_path, markdown)
  output_path.dirname.mkpath
  temp_path = output_path.dirname + ".#{output_path.basename}.tmp-#{Process.pid}"
  temp_path.write(markdown)
  FileUtils.mv(temp_path.to_s, output_path.to_s)
ensure
  temp_path&.delete if temp_path&.exist?
end

def run(argv)
  options = parse_options(argv)
  report = build_report(options.vault_root)
  output_path = resolve_output_path(options)
  write_report(output_path, render_report(report))
  puts "report: #{relative_or_absolute(output_path, options.vault_root)}"
end

begin
  run(ARGV)
rescue NousReportError => error
  warn "generate_nous_report: #{error.message}"
  exit 1
end
