# frozen_string_literal: true

require "date"
require "json"
require "pathname"
require "psych"
require "set"
require "time"

require_relative "nous/path_guard"
require_relative "nous/vault_lock"
require_relative "nous/atomic_writer"
require_relative "nous/file_transaction"
require_relative "nous/collision_allocator"
require_relative "nous/text_ingestion"
require_relative "nous/artifact_ingestion"
require_relative "nous/relationship_integrity"
require_relative "nous/review_mutation"

module Nous
  SCHEMA_VERSION = "0.1"
  SUMMARY_MAX_LENGTH = 240
  EXCERPT_MAX_LENGTH = 240
  EXCLUDED_REVIEW_STATUSES = ["rejected", "deprecated"].freeze

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

  PENDING_REVIEW_STATUSES = ["agent_generated", "needs_review"].freeze
  INBOX_DIRS = {
    "note" => "01_agent_inbox/notes",
    "claim" => "01_agent_inbox/claims",
    "relationship" => "01_agent_inbox/relationships"
  }.freeze
  KIND_PRIORITY = {
    "claim" => 10,
    "relationship" => 20,
    "note" => 30
  }.freeze

  class Error < StandardError
    attr_reader :code, :details

    def initialize(message, code: "NOUS_INVALID_INPUT", details: {})
      super(message)
      @code = code
      @details = details
    end
  end

  Record = Struct.new(:path, :relative_path, :frontmatter, :body, :record_kind, keyword_init: true)
  ReportEntry = Struct.new(:id, :type, :label, :source_path, :confidence, :excerpt, :evidence, :created, keyword_init: true)
  Relationship = Struct.new(:id, :from, :to, :type, :confidence, :source_path, keyword_init: true)

  ReviewItem = Struct.new(:path, :relative_path, :kind, :frontmatter, :body, keyword_init: true) do
    def review_status
      Nous.string_value(frontmatter["review_status"], strip: false)
    end

    def created
      Nous.string_value(frontmatter["created"], strip: false)
    end

    def confidence
      raw = frontmatter["confidence"]
      return nil if raw.nil? || raw == ""

      Float(raw)
    rescue ArgumentError, TypeError
      nil
    end

    def priority
      manual = frontmatter["priority"]
      return Integer(manual) unless manual.nil? || manual == ""

      confidence_penalty = confidence.nil? ? 10 : ((1.0 - confidence) * 10).round
      KIND_PRIORITY.fetch(kind, 90) + confidence_penalty
    rescue ArgumentError, TypeError
      KIND_PRIORITY.fetch(kind, 90) + 10
    end

    def evidence_paths
      paths = []
      evidence = frontmatter["evidence"]
      if evidence.is_a?(Array)
        evidence.each do |entry|
          next unless entry.is_a?(Hash) && entry["path"]

          paths << Nous.string_value(entry["path"], strip: false)
        end
      end

      source = frontmatter["source"]
      paths << Nous.string_value(source["path"], strip: false) if source.is_a?(Hash) && source["path"]
      paths.uniq
    end
  end

  module_function

  def string_value(raw, strip: true)
    value = raw.nil? ? "" : raw.to_s
    strip ? value.strip : value
  end

  def relative_or_absolute(path, base)
    path = Pathname(path)
    base = Pathname(base)
    relative = path.expand_path.relative_path_from(base.expand_path)
    relative.to_s.start_with?("..") ? path.to_s : relative.to_s
  rescue ArgumentError
    path.to_s
  end

  def markdown_files(directory)
    directory = Pathname(directory)
    return [] unless directory.directory?

    directory.children.select do |path|
      path.file? && path.extname == ".md" && path.basename.to_s != "AGENT.md"
    end
  end

  def yaml_frontmatter(data)
    Psych.dump(data).sub(/\A---\n/, "")
  end

  def parse_markdown(path, permitted_classes: [], error_path: nil)
    path = Pathname(path)
    text = path.read
    match = text.match(/\A---\n(.*?)\n---\n?/m)
    display_path = error_path || path
    raise Error.new("missing YAML frontmatter: #{display_path}", code: "NOUS_PARSE_FAILED") unless match

    frontmatter = Psych.safe_load(match[1], permitted_classes: permitted_classes, aliases: false) || {}
    unless frontmatter.is_a?(Hash)
      raise Error.new("frontmatter must be a mapping: #{display_path}", code: "NOUS_PARSE_FAILED")
    end

    [frontmatter, text[match[0].length..] || ""]
  rescue Psych::Exception => error
    raise Error.new("invalid YAML frontmatter in #{display_path}: #{error.message}", code: "NOUS_PARSE_FAILED")
  end

  def reviewed_note_files(vault_root)
    notes_root = Pathname(vault_root) + "02_notes"
    return [] unless notes_root.directory?

    notes_root.children.select(&:directory?).flat_map { |directory| markdown_files(directory) }
  end

  def export_record_files(vault_root)
    vault_root = Pathname(vault_root)
    reviewed_note_files(vault_root) +
      markdown_files(vault_root + "03_canonical_model/claims") +
      markdown_files(vault_root + "03_canonical_model/relationships")
  end

  def record_kind_for(relative_path)
    return "claim" if relative_path.start_with?("03_canonical_model/claims/")
    return "relationship" if relative_path.start_with?("03_canonical_model/relationships/")

    "note"
  end

  def load_records(vault_root, permitted_classes:)
    vault_root = Pathname(vault_root).expand_path
    export_record_files(vault_root).sort_by(&:to_s).map do |path|
      relative_path = relative_or_absolute(path, vault_root)
      frontmatter, body = parse_markdown(path, permitted_classes: permitted_classes, error_path: relative_path)
      Record.new(
        path: path,
        relative_path: relative_path,
        frontmatter: frontmatter,
        body: body,
        record_kind: record_kind_for(relative_path)
      )
    end
  end

  def excluded_record?(record)
    review_status = string_value(record.frontmatter["review_status"])
    status = string_value(record.frontmatter["status"])
    EXCLUDED_REVIEW_STATUSES.include?(review_status) || status == "archived"
  end

  def require_field(record, field)
    value = string_value(record.frontmatter[field])
    if value.empty?
      raise Error.new("missing #{field}: #{record.relative_path}", code: "NOUS_INVALID_INPUT", details: { path: record.relative_path, field: field })
    end

    value
  end

  def exportable_record?(record)
    return false if excluded_record?(record)

    review_status = require_field(record, "review_status")
    status = require_field(record, "status")

    review_status == "reviewed" && status != "archived"
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

  def bounded_body_line(body, length)
    line = body.each_line.map(&:strip).find { |value| !value.empty? && !value.start_with?("#") }
    return nil if line.nil? || line.empty?

    line[0, length]
  end

  def graph_evidence(frontmatter)
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

  def report_evidence(frontmatter)
    evidence = frontmatter["evidence"]
    return [] if evidence.nil?
    return [report_evidence_entry(evidence)].compact unless evidence.is_a?(Array)

    seen = {}
    evidence.each_with_object([]) do |entry, refs|
      normalized = report_evidence_entry(entry)
      next if normalized.nil?

      key = [normalized.fetch("id"), normalized.fetch("path")]
      next if seen[key]

      seen[key] = true
      refs << normalized
    end
  end

  def report_evidence_entry(entry)
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
    unless value >= 0 && value <= 1
      raise Error.new("confidence must be between 0 and 1: #{record.relative_path}", code: "NOUS_INVALID_INPUT")
    end

    value
  rescue ArgumentError, TypeError
    raise Error.new("confidence must be numeric: #{record.relative_path}", code: "NOUS_INVALID_INPUT")
  end

  module Graph
    module_function

    def build(vault_root:, generated_at:)
      nodes = []
      edges = []
      Nous.load_records(vault_root, permitted_classes: []).each do |record|
        next unless Nous.exportable_record?(record)

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
        "generated_at" => normalize_time(generated_at),
        "nodes" => without_internal_fields(nodes),
        "edges" => without_internal_fields(edges)
      }
    end

    def render(graph)
      "#{JSON.pretty_generate(graph)}\n"
    end

    def normalize_time(value)
      return value.utc.iso8601 if value.respond_to?(:utc) && value.respond_to?(:iso8601)

      Time.iso8601(value.to_s).utc.iso8601
    rescue ArgumentError
      raise Error.new("generated_at must be an ISO-8601 timestamp", code: "NOUS_INVALID_INPUT")
    end

    def relationship_record?(record)
      Nous.string_value(record.frontmatter["type"]) == "relationship"
    end

    def node_from(record)
      id = Nous.require_field(record, "id")
      type = Nous.require_field(record, "type")
      unless SUPPORTED_NODE_TYPES.include?(type)
        raise Error.new("unsupported node type #{type.inspect}: #{record.relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
      end

      node = {
        "id" => id,
        "type" => type,
        "label" => Nous.label_for(record, id),
        "review_status" => "reviewed",
        "evidence" => Nous.graph_evidence(record.frontmatter)
      }
      confidence = Nous.confidence_value(record)
      node["confidence"] = confidence unless confidence.nil?
      summary = Nous.bounded_body_line(record.body, SUMMARY_MAX_LENGTH)
      node["summary"] = summary unless summary.nil? || summary.empty?
      node["source_path"] = record.relative_path
      node
    end

    def relationship_data(record)
      relationship = record.frontmatter["relationship"]
      unless relationship.is_a?(Hash)
        raise Error.new("missing relationship mapping: #{record.relative_path}", code: "NOUS_INVALID_INPUT")
      end

      relationship
    end

    def relationship_field(record, relationship, field)
      value = Nous.string_value(relationship[field])
      if value.empty?
        raise Error.new("missing relationship.#{field}: #{record.relative_path}", code: "NOUS_INVALID_INPUT")
      end

      value
    end

    def edge_from(record)
      type = Nous.require_field(record, "type")
      unless type == "relationship"
        raise Error.new("unsupported edge record type #{type.inspect}: #{record.relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
      end

      relationship = relationship_data(record)
      relationship_type = relationship_field(record, relationship, "type")
      unless SUPPORTED_RELATIONSHIP_TYPES.include?(relationship_type)
        raise Error.new("unsupported relationship type #{relationship_type.inspect}: #{record.relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
      end

      edge = {
        "id" => Nous.require_field(record, "id"),
        "from" => relationship_field(record, relationship, "from"),
        "to" => relationship_field(record, relationship, "to"),
        "relationship" => relationship_type,
        "review_status" => "reviewed",
        "evidence" => Nous.graph_evidence(record.frontmatter)
      }
      confidence = Nous.confidence_value(record)
      edge["confidence"] = confidence unless confidence.nil?
      edge
    end

    def reject_unexpected_directory_type!(record)
      if relationship_record?(record) && !record.relative_path.start_with?("03_canonical_model/relationships/")
        raise Error.new("relationship export records must be canonical relationships: #{record.relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
      end

      if record.relative_path.start_with?("03_canonical_model/relationships/") && !relationship_record?(record)
        raise Error.new("relationship export record must have type relationship: #{record.relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
      end

      return unless record.relative_path.start_with?("03_canonical_model/claims/")
      return if Nous.string_value(record.frontmatter["type"]) == "claim"

      raise Error.new("claim export record must have type claim: #{record.relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
    end

    def ensure_unique!(records, kind)
      seen = {}
      records.each do |record|
        id = record.fetch("id")
        if seen.key?(id)
          raise Error.new(
            "duplicate #{kind} id #{id.inspect}: #{seen.fetch(id)} and #{record.fetch("_source_path")}",
            code: "NOUS_DUPLICATE_ID"
          )
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

        raise Error.new("dangling edge #{edge.fetch("id").inspect}: missing node id #{missing.join(", ")}", code: "NOUS_INVALID_ENDPOINT")
      end
    end
  end

  module Report
    module_function

    def build(vault_root:, generated_at:)
      sections = SECTION_DEFINITIONS.to_h { |title, _directory, _type| [title, []] }
      claims = []
      relationships = []

      Nous.load_records(vault_root, permitted_classes: [Date, Time]).each do |record|
        next if record.record_kind == "note" && !supported_note_record?(record)
        next unless Nous.exportable_record?(record)

        case record.record_kind
        when "note"
          title, _directory, expected_type = SECTION_DEFINITIONS.find { |_section_title, directory, _type| directory == note_directory(record) }
          sections.fetch(title) << report_entry_from(record, expected_type: expected_type)
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
        generated_at: Graph.normalize_time(generated_at),
        sections: sections.transform_values { |entries_for_section| sort_entries(entries_for_section) },
        claims: sort_entries(claims),
        relationships: relationships.sort_by(&:id)
      }
    end

    def render(report)
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

    def note_directory(record)
      parts = record.relative_path.split("/")
      return nil unless parts[0] == "02_notes"

      parts[1]
    end

    def supported_note_record?(record)
      record.record_kind == "note" && SUPPORTED_NOTE_DIRECTORIES.include?(note_directory(record))
    end

    def report_entry_from(record, expected_type: nil)
      id = Nous.require_field(record, "id")
      type = Nous.require_field(record, "type")
      if expected_type && type != expected_type
        raise Error.new("expected type #{expected_type.inspect}, got #{type.inspect}: #{record.relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
      end

      ReportEntry.new(
        id: id,
        type: type,
        label: Nous.label_for(record, id),
        source_path: record.relative_path,
        confidence: Nous.confidence_value(record),
        excerpt: Nous.bounded_body_line(record.body, EXCERPT_MAX_LENGTH),
        evidence: Nous.report_evidence(record.frontmatter),
        created: Nous.string_value(record.frontmatter["created"])
      )
    end

    def claim_entry_from(record)
      type = Nous.require_field(record, "type")
      unless type == "claim"
        raise Error.new("claim report record must have type claim: #{record.relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
      end

      report_entry_from(record, expected_type: "claim")
    end

    def relationship_mapping(record)
      relationship = record.frontmatter["relationship"]
      unless relationship.is_a?(Hash)
        raise Error.new("missing relationship mapping: #{record.relative_path}", code: "NOUS_INVALID_INPUT")
      end

      relationship
    end

    def relationship_field(record, relationship, field)
      value = Nous.string_value(relationship[field])
      if value.empty?
        raise Error.new("missing relationship.#{field}: #{record.relative_path}", code: "NOUS_INVALID_INPUT")
      end

      value
    end

    def relationship_from(record)
      type = Nous.require_field(record, "type")
      unless type == "relationship"
        raise Error.new("relationship report record must have type relationship: #{record.relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
      end

      relationship = relationship_mapping(record)
      relationship_type = relationship_field(record, relationship, "type")
      unless SUPPORTED_RELATIONSHIP_TYPES.include?(relationship_type)
        raise Error.new("unsupported relationship type #{relationship_type.inspect}: #{record.relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
      end

      Relationship.new(
        id: Nous.require_field(record, "id"),
        from: relationship_field(record, relationship, "from"),
        to: relationship_field(record, relationship, "to"),
        type: relationship_type,
        confidence: Nous.confidence_value(record),
        source_path: record.relative_path
      )
    end

    def sort_entries(entries)
      entries.sort_by { |entry| [entry.created.empty? ? "9999-99-99" : entry.created, entry.id] }
    end

    def ensure_unique_entries!(entries)
      seen = {}
      entries.each do |entry|
        if seen.key?(entry.id)
          raise Error.new("duplicate record id #{entry.id.inspect}: #{seen.fetch(entry.id)} and #{entry.source_path}", code: "NOUS_DUPLICATE_ID")
        end

        seen[entry.id] = entry.source_path
      end
    end

    def ensure_unique_relationships!(relationships)
      seen = {}
      relationships.each do |relationship|
        if seen.key?(relationship.id)
          raise Error.new(
            "duplicate relationship id #{relationship.id.inspect}: #{seen.fetch(relationship.id)} and #{relationship.source_path}",
            code: "NOUS_DUPLICATE_ID"
          )
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
  end

  module Review
    module_function

    def load_item(path, vault_root:)
      path = Pathname(path)
      vault_root = Pathname(vault_root).expand_path
      raise Error.new("review item does not exist", code: "NOUS_RECORD_NOT_FOUND") unless path.file?

      kind = kind_for_path(path, vault_root)
      if kind.nil?
        raise Error.new("path is not in a review inbox", code: "NOUS_INVALID_INPUT")
      end

      relative_path = Nous.relative_or_absolute(path, vault_root)
      frontmatter, body = Nous.parse_markdown(path, error_path: relative_path)
      ReviewItem.new(path: path, relative_path: relative_path, kind: kind, frontmatter: frontmatter, body: body)
    end

    def inbox_items(vault_root:)
      vault_root = Pathname(vault_root).expand_path
      INBOX_DIRS.flat_map do |kind, directory|
        inbox = vault_root + directory
        next [] unless inbox.directory?

        Nous.markdown_files(inbox).map do |path|
          relative_path = Nous.relative_or_absolute(path, vault_root)
          frontmatter, body = Nous.parse_markdown(path, error_path: relative_path)
          ReviewItem.new(path: path, relative_path: relative_path, kind: kind, frontmatter: frontmatter, body: body)
        end
      end
    end

    def list(vault_root:, sort: "priority")
      sorted_items(inbox_items(vault_root: vault_root).select { |item| pending_item?(item) }, sort)
    end

    def render_list(items)
      lines = ["priority\tkind\tpath\treview_status\tcreated\tconfidence\tevidence"]
      items.each do |item|
        lines << [
          item.priority,
          item.kind,
          item.relative_path,
          item.review_status,
          item.created,
          item.confidence.nil? ? "" : item.confidence,
          item.evidence_paths.join(", ")
        ].join("\t")
      end
      "#{lines.join("\n")}\n"
    end

    def show(path:, vault_root:)
      load_item(path, vault_root: vault_root)
    end

    def render_show(item)
      lines = []
      lines << "Path: #{item.relative_path}"
      lines << "Kind: #{item.kind}"
      lines << "Review status: #{item.review_status}"
      lines << "Created: #{item.created}"
      lines << "Confidence: #{item.confidence}" unless item.confidence.nil?
      lines << "Evidence:"
      if item.evidence_paths.empty?
        lines << "- (none)"
      else
        item.evidence_paths.each { |evidence_path| lines << "- #{evidence_path}" }
      end
      lines << ""
      lines << "--- Frontmatter ---"
      lines << Nous.yaml_frontmatter(item.frontmatter).rstrip
      lines << "--- Body ---"
      lines << item.body.rstrip
      "#{lines.join("\n")}\n"
    end

    def report(vault_root:, generated_at:)
      {
        generated_at: Graph.normalize_time(generated_at),
        items: list(vault_root: vault_root, sort: "priority")
      }
    end

    def render_report(report)
      items = report.fetch(:items)
      lines = [
        "# Review Queue",
        "",
        "- Generated: #{report.fetch(:generated_at)}",
        "- Pending items: #{items.length}",
        "",
        "| Priority | Kind | Created | Confidence | Status | Path | Evidence |",
        "| --- | --- | --- | --- | --- | --- | --- |"
      ]

      items.each do |item|
        lines << [
          item.priority,
          item.kind,
          item.created,
          item.confidence.nil? ? "" : item.confidence,
          item.review_status,
          item.relative_path,
          item.evidence_paths.join(", ")
        ].map { |cell| markdown_cell(cell) }.join(" | ").then { |row| "| #{row} |" }
      end

      lines << ""
      lines << "No pending review items." if items.empty?
      "#{lines.join("\n")}\n"
    end

    def kind_for_path(path, vault_root)
      relative = Nous.relative_or_absolute(path, vault_root)
      INBOX_DIRS.each do |kind, directory|
        return kind if relative.start_with?("#{directory}/")
      end

      nil
    end

    def pending_item?(item)
      PENDING_REVIEW_STATUSES.include?(item.review_status) && item.frontmatter["status"].to_s != "archived"
    end

    def sorted_items(items, sort)
      case sort
      when "priority"
        items.sort_by { |item| [item.priority, item.created, item.relative_path] }
      when "created"
        items.sort_by { |item| [item.created, item.relative_path] }
      when "confidence"
        items.sort_by { |item| [item.confidence.nil? ? 1 : 0, -(item.confidence || 0), item.relative_path] }
      else
        raise Error.new("unsupported sort field: #{sort}", code: "NOUS_INVALID_INPUT")
      end
    end

    def markdown_cell(value)
      value.to_s.gsub("|", "\\|")
    end
  end
end
