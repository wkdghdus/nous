# frozen_string_literal: true

require "digest"

module Nous
  DEFAULT_RECORD_SCOPES = ["reviewed", "canonical"].freeze
  READ_RECORD_DEFAULT_MAX_CHARS = 12_000
  READ_RECORD_MAX_CHARS = 50_000
  READ_SOURCE_DEFAULT_MAX_CHARS = 12_000
  READ_SOURCE_MAX_CHARS = 50_000
  LIST_RECORD_DEFAULT_LIMIT = 20
  LIST_RECORD_MAX_LIMIT = 50
  LIST_EXCERPT_MAX_CHARS = 240
  LIST_EVIDENCE_MAX = 10
  SOURCE_TEXT_EXTENSIONS = [".txt", ".md", ".json", ".yaml", ".yml"].freeze
  SOURCE_BINARY_EXTENSIONS = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic"].freeze

  module_function

  def status(vault_root:)
    VaultLock.new(vault_root: vault_root).with_shared do
      status_in_context(RecordIndex.scan(vault_root: vault_root))
    end
  end

  def status_in_context(context)
    records = context.records
    {
      "vault_schema_version" => SCHEMA_VERSION,
      "record_count" => records.length,
      "counts" => {
        "by_lifecycle" => count_by(records, &:lifecycle),
        "by_kind" => count_by(records, &:kind),
        "by_scope" => count_by(records, &:scope)
      },
      "generated" => generated_presence(context.vault_root),
      "warnings" => context.diagnostics
    }
  end

  def list_records(vault_root:, query: nil, scopes: nil, types: nil, limit: LIST_RECORD_DEFAULT_LIMIT)
    VaultLock.new(vault_root: vault_root).with_shared do
      context = RecordIndex.scan!(vault_root: vault_root, scopes: normalize_scopes(scopes))
      list_records_in_context(context, query: query, scopes: scopes, types: types, limit: limit)
    end
  end

  def list_records_in_context(context, query: nil, scopes: nil, types: nil, limit: LIST_RECORD_DEFAULT_LIMIT)
    selected_scopes = normalize_scopes(scopes)
    selected_types = normalize_types(types)
    selected_limit = normalize_limit(limit)
    normalized_query = normalize_query(query)

    duplicates = duplicates_for(context.records.select { |record| selected_scopes.include?(record.scope) })
    unless duplicates.empty?
      id, paths = duplicates.sort.first
      raise Error.new("duplicate record id", code: "NOUS_DUPLICATE_ID", details: { id: id, count: paths.length })
    end

    records = context.records.select do |record|
      selected_scopes.include?(record.scope) &&
        record.lifecycle != "retired" &&
        (selected_types.nil? || selected_types.include?(record.type) || selected_types.include?(record.kind))
    end

    ranked = records.map do |record|
      score = lexical_score(record, normalized_query)
      next if normalized_query && score <= 0

      [record, score]
    end.compact

    ranked.sort_by! { |record, score| [-score, record.id, record.relative_path] }
    result_records = ranked.first(selected_limit).map { |record, score| summary_for(record, score: score) }
    {
      "records" => result_records,
      "limit" => selected_limit,
      "query" => normalized_query.to_s,
      "scopes" => selected_scopes,
      "types" => selected_types,
      "truncated" => ranked.length > selected_limit,
      "content_role" => "untrusted_data"
    }
  end

  def read_record(vault_root:, id:, max_chars: READ_RECORD_DEFAULT_MAX_CHARS)
    VaultLock.new(vault_root: vault_root).with_shared do
      context = RecordIndex.scan!(vault_root: vault_root)
      read_record_in_context(context, id: id, max_chars: max_chars)
    end
  end

  def read_record_in_context(context, id:, max_chars: READ_RECORD_DEFAULT_MAX_CHARS)
    selected_max = normalize_body_limit(max_chars)
    key = string_value(id)
    record = context.unique_record!(key)
    body = record.body.to_s
    body_chars = body.each_char.to_a
    visible_body = selected_max.zero? ? "" : body_chars.first(selected_max).join
    envelope = base_envelope(record).merge(
      "body" => visible_body,
      "body_total_chars" => body_chars.length,
      "body_returned_chars" => visible_body.each_char.count,
      "body_truncated" => body_chars.length > selected_max,
      "max_chars" => selected_max,
      "content_role" => "untrusted_data"
    )
    envelope.delete("body") if selected_max.zero?
    envelope
  end

  def read_source_text(vault_root:, artifact_id:, offset_chars: 0, max_chars: READ_SOURCE_DEFAULT_MAX_CHARS)
    VaultLock.new(vault_root: vault_root).with_shared do
      context = RecordIndex.scan!(vault_root: vault_root)
      read_source_text_in_context(context, artifact_id: artifact_id, offset_chars: offset_chars, max_chars: max_chars)
    end
  end

  def read_source_text_in_context(context, artifact_id:, offset_chars: 0, max_chars: READ_SOURCE_DEFAULT_MAX_CHARS)
    selected_offset = normalize_offset(offset_chars)
    selected_max = normalize_source_limit(max_chars)
    key = string_value(artifact_id)
    indexed = context.unique_record!(key)
    unless indexed.kind == "artifact"
      raise Error.new("record is not a source artifact", code: "NOUS_UNSUPPORTED_SOURCE", details: { id: key })
    end

    source = indexed.frontmatter["source"]
    source_type = source.is_a?(Hash) ? string_value(source["type"]) : ""
    path_value = source.is_a?(Hash) ? string_value(source["path"], strip: false) : ""

    if indexed.relative_path.start_with?("00_raw_artifacts/text/")
      text = observed_content(indexed.body)
      return source_text_result(
        indexed,
        text: text,
        offset_chars: selected_offset,
        max_chars: selected_max,
        source_kind: "embedded_observed_content",
        warnings: []
      )
    end

    if indexed.relative_path.start_with?("00_raw_artifacts/images/notes/")
      return unavailable_source_result(indexed, reason: "image_source_unavailable")
    end

    unless source.is_a?(Hash) && !path_value.empty?
      raise Error.new("artifact source metadata is missing copied payload", code: "NOUS_UNSUPPORTED_SOURCE", details: { id: key })
    end

    payload_relative = safe_payload_relative!(path_value)
    validate_payload_directory!(indexed, payload_relative)
    if binary_payload?(payload_relative)
      return unavailable_source_result(indexed, reason: unavailable_reason_for(source_type), payload_path: payload_relative)
    end
    unless text_payload?(payload_relative)
      raise Error.new("unsupported source payload type", code: "NOUS_UNSUPPORTED_SOURCE", details: { id: key })
    end

    payload_path = payload_path!(context.vault_root, payload_relative)
    bytes = payload_path.binread
    verify_payload_metadata!(bytes, payload_path, source)
    text = bytes.dup.force_encoding("UTF-8")
    unless text.valid_encoding?
      raise Error.new("source payload must be valid UTF-8", code: "NOUS_UNSUPPORTED_SOURCE", details: { id: key })
    end

    source_text_result(
      indexed,
      text: text,
      offset_chars: selected_offset,
      max_chars: selected_max,
      source_kind: "copied_payload",
      payload_path: payload_relative,
      warnings: source_metadata_warnings(source)
    )
  rescue Errno::ENOENT
    raise Error.new("source payload is missing", code: "NOUS_RECORD_NOT_FOUND", details: { id: string_value(artifact_id) })
  end

  def normalize_scopes(scopes)
    values = scopes.nil? ? DEFAULT_RECORD_SCOPES : Array(scopes).map { |scope| string_value(scope) }
    raise Error.new("at least one scope is required", code: "NOUS_INVALID_INPUT") if values.empty? || values.any?(&:empty?)
    raise Error.new("duplicate scopes are not allowed", code: "NOUS_INVALID_INPUT") unless values.uniq.length == values.length

    invalid = values - RecordIndex::SCOPES.keys
    raise Error.new("unsupported record scope", code: "NOUS_INVALID_INPUT", details: { scopes: invalid }) unless invalid.empty?

    values
  end

  def normalize_types(types)
    return nil if types.nil?

    values = Array(types).map { |type| string_value(type) }
    raise Error.new("duplicate types are not allowed", code: "NOUS_INVALID_INPUT") unless values.uniq.length == values.length
    raise Error.new("record types must not be empty", code: "NOUS_INVALID_INPUT") if values.empty? || values.any?(&:empty?)

    invalid = values - RecordIndex::SUPPORTED_TYPES
    raise Error.new("unsupported record type", code: "NOUS_UNSUPPORTED_RECORD_TYPE", details: { types: invalid }) unless invalid.empty?

    values
  end

  def normalize_limit(limit)
    value = Integer(limit)
    unless value >= 1 && value <= LIST_RECORD_MAX_LIMIT
      raise Error.new("limit must be between 1 and #{LIST_RECORD_MAX_LIMIT}", code: "NOUS_INVALID_INPUT")
    end

    value
  rescue ArgumentError, TypeError
    raise Error.new("limit must be an integer", code: "NOUS_INVALID_INPUT")
  end

  def normalize_body_limit(max_chars)
    value = Integer(max_chars)
    unless value >= 0 && value <= READ_RECORD_MAX_CHARS
      raise Error.new("max_chars must be between 0 and #{READ_RECORD_MAX_CHARS}", code: "NOUS_INVALID_INPUT")
    end

    value
  rescue ArgumentError, TypeError
    raise Error.new("max_chars must be an integer", code: "NOUS_INVALID_INPUT")
  end

  def normalize_source_limit(max_chars)
    value = Integer(max_chars)
    unless value >= 1 && value <= READ_SOURCE_MAX_CHARS
      raise Error.new("max_chars must be between 1 and #{READ_SOURCE_MAX_CHARS}", code: "NOUS_INVALID_INPUT")
    end

    value
  rescue ArgumentError, TypeError
    raise Error.new("max_chars must be an integer", code: "NOUS_INVALID_INPUT")
  end

  def normalize_offset(offset_chars)
    value = Integer(offset_chars)
    raise Error.new("offset_chars must be non-negative", code: "NOUS_INVALID_INPUT") if value.negative?

    value
  rescue ArgumentError, TypeError
    raise Error.new("offset_chars must be an integer", code: "NOUS_INVALID_INPUT")
  end

  def normalize_query(query)
    return nil if query.nil?

    value = query.to_s.strip
    raise Error.new("query must be 500 characters or fewer", code: "NOUS_INVALID_INPUT") if value.length > 500

    value.empty? ? nil : value
  end

  def count_by(records)
    records.each_with_object(Hash.new(0)) { |record, counts| counts[yield(record)] += 1 }.sort.to_h
  end

  def generated_presence(root)
    {
      "graph" => (root + "04_generated/graph/nous_graph.json").file?,
      "report" => (root + "04_generated/reports/nous.md").file?,
      "review_queue_report" => (root + "04_generated/reports/review_queue.md").file?
    }
  end

  def duplicates_for(records)
    records.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, grouped|
      grouped[record.id] << record.relative_path unless record.id.empty?
    end.select { |_id, paths| paths.length > 1 }
  end

  def lexical_score(record, query)
    return 1 if query.nil?

    q = query.downcase
    tokens = q.split(/\s+/).reject(&:empty?).first(20)
    label = label_for(record.record, record.id).downcase
    tags = Array(record.frontmatter["tags"]).map(&:to_s).join(" ").downcase
    evidence = normalized_refs(record.frontmatter["evidence"]).map { |entry| entry.values.join(" ") }.join(" ").downcase
    body = record.body.to_s.downcase

    return 100 if record.id.downcase == q
    return 90 if label == q

    score = 0
    score += 70 if label.include?(q)
    score += 50 if tags.include?(q)
    score += 45 if evidence.include?(q)
    score += 20 if body.include?(q)
    tokens.each do |token|
      score += 8 if record.id.downcase.include?(token)
      score += 6 if label.include?(token)
      score += 4 if tags.include?(token)
      score += 3 if evidence.include?(token)
      score += 1 if body.include?(token)
    end
    score
  end

  def summary_for(indexed, score:)
    base_envelope(indexed).merge(
      "excerpt" => bounded_text(indexed.body, LIST_EXCERPT_MAX_CHARS),
      "search_score" => score,
      "content_role" => "untrusted_data"
    )
  end

  def base_envelope(indexed)
    fm = indexed.frontmatter
    {
      "id" => indexed.id,
      "type" => indexed.type,
      "kind" => indexed.kind,
      "lifecycle" => indexed.lifecycle,
      "status" => string_value(fm["status"]),
      "review_status" => string_value(fm["review_status"]),
      "path" => indexed.relative_path,
      "label" => label_for(indexed.record, indexed.id),
      "created" => safe_scalar(fm["created"]),
      "updated" => safe_scalar(fm["updated"]),
      "confidence" => numeric_or_nil(fm["confidence"]),
      "tags" => safe_string_array(fm["tags"]),
      "source" => sanitized_source(fm["source"]),
      "evidence" => bounded_refs(fm["evidence"]),
      "counterevidence" => bounded_refs(fm["counterevidence"])
    }.compact
  end

  def bounded_text(text, max_chars)
    line = text.to_s.each_line.map(&:strip).find { |value| !value.empty? && !value.start_with?("#") }
    return nil if line.nil? || line.empty?

    chars = line.each_char.to_a
    suffix = chars.length > max_chars ? "…" : ""
    chars.first(max_chars).join + suffix
  end

  def bounded_refs(value)
    refs = normalized_refs(value)
    result = refs.first(LIST_EVIDENCE_MAX)
    { "items" => result, "truncated" => refs.length > LIST_EVIDENCE_MAX }
  end

  def normalized_refs(value)
    values = value.is_a?(Array) ? value : [value].compact
    seen = {}
    values.each_with_object([]) do |entry, refs|
      normalized = if entry.is_a?(Hash)
                     id = string_value(entry["id"])
                     path = safe_relative_path_value(entry["path"])
                     next if id.empty? && path.empty?

                     { "id" => id, "path" => path.empty? ? id : path }
                   else
                     text = safe_relative_path_value(entry)
                     next if text.empty?

                     { "id" => "", "path" => text }
                   end
      key = [normalized["id"], normalized["path"]]
      next if seen[key]

      seen[key] = true
      refs << normalized
    end
  end

  def sanitized_source(source)
    return nil unless source.is_a?(Hash)

    allowed = {}
    %w[type extraction_method original_filename represented_date sha256 bytes].each do |key|
      value = source[key]
      allowed[key] = safe_scalar(value) unless value.nil? || safe_scalar(value).empty?
    end
    path = safe_relative_path_value(source["path"])
    allowed["path"] = path unless path.empty?
    allowed
  end

  def safe_relative_path_value(value)
    text = string_value(value, strip: false)
    return "" if text.empty?

    path = Pathname(text)
    return "[redacted_external_path]" if path.absolute?
    return "[redacted_unsafe_path]" if path.each_filename.any? { |part| part == ".." }

    text
  end

  def safe_scalar(value)
    return "" if value.nil?

    value.to_s
  end

  def safe_string_array(value)
    return [] unless value.is_a?(Array)

    value.map { |entry| string_value(entry) }.reject(&:empty?).uniq.first(50)
  end

  def numeric_or_nil(value)
    return nil if value.nil? || value == ""

    Float(value)
  rescue ArgumentError, TypeError
    nil
  end

  def observed_content(body)
    match = body.to_s.match(/^## Observed Content[ \t]*\n(?<content>.*?)(?=^## |\z)/m)
    raise Error.new("artifact observed content is missing", code: "NOUS_UNSUPPORTED_SOURCE") if match.nil?

    match[:content].sub(/\A\n/, "").rstrip
  end

  def source_text_result(indexed, text:, offset_chars:, max_chars:, source_kind:, payload_path: nil, warnings: [])
    chars = text.each_char.to_a
    if offset_chars > chars.length
      raise Error.new("offset_chars exceeds source length", code: "NOUS_INVALID_INPUT", details: { id: indexed.id })
    end

    chunk = chars.drop(offset_chars).first(max_chars).join
    next_offset = offset_chars + chunk.each_char.count
    result = {
      "id" => indexed.id,
      "type" => indexed.type,
      "kind" => indexed.kind,
      "lifecycle" => indexed.lifecycle,
      "path" => indexed.relative_path,
      "source_kind" => source_kind,
      "content_available" => true,
      "content_role" => "untrusted_data",
      "text" => chunk,
      "offset_chars" => offset_chars,
      "max_chars" => max_chars,
      "returned_chars" => chunk.each_char.count,
      "total_chars" => chars.length,
      "next_offset_chars" => next_offset,
      "truncated" => next_offset < chars.length,
      "warnings" => warnings
    }
    result["payload_path"] = payload_path unless payload_path.nil?
    result
  end

  def unavailable_source_result(indexed, reason:, payload_path: nil)
    result = base_envelope(indexed).merge(
      "content_available" => false,
      "content_unavailable_reason" => reason,
      "content_role" => "untrusted_data"
    )
    result["payload_path"] = payload_path unless payload_path.nil?
    result
  end

  def safe_payload_relative!(value)
    text = string_value(value, strip: false)
    path = Pathname(text)
    if text.empty? || path.absolute? || path.each_filename.any? { |part| part == ".." }
      raise Error.new("unsafe source payload path", code: "NOUS_PATH_OUTSIDE_VAULT")
    end

    text
  end

  def text_payload?(relative_path)
    SOURCE_TEXT_EXTENSIONS.include?(Pathname(relative_path).extname.downcase)
  end

  def binary_payload?(relative_path)
    SOURCE_BINARY_EXTENSIONS.include?(Pathname(relative_path).extname.downcase)
  end

  def unavailable_reason_for(source_type)
    return "image_source_unavailable" if source_type == "image"

    "binary_source_unavailable"
  end

  def validate_payload_directory!(indexed, relative_path)
    allowed_prefixes = if indexed.relative_path.start_with?("00_raw_artifacts/writing/notes/")
                         ["00_raw_artifacts/writing/files/"]
                       elsif indexed.relative_path.start_with?("00_raw_artifacts/projects/notes/")
                         ["00_raw_artifacts/projects/files/"]
                       else
                         []
                       end
    return if allowed_prefixes.any? { |prefix| relative_path.start_with?(prefix) }

    raise Error.new("unsafe source payload path", code: "NOUS_PATH_OUTSIDE_VAULT", details: { id: indexed.id })
  end

  def payload_path!(vault_root, relative_path)
    PathGuard.internal_path(vault_root: vault_root, path: relative_path)
  rescue Nous::Error => error
    raise error if error.code == "NOUS_SYMLINK_REJECTED"
    raise Error.new("source payload is missing", code: error.code)
  end

  def verify_payload_metadata!(bytes, payload_path, source)
    sha = string_value(source["sha256"])
    expected_bytes = source["bytes"]
    unless sha.empty?
      actual_sha = Digest::SHA256.hexdigest(bytes)
      raise Error.new("source payload checksum mismatch", code: "NOUS_UNSUPPORTED_SOURCE") unless actual_sha == sha
    end
    return if expected_bytes.nil? || expected_bytes == ""

    expected = Integer(expected_bytes)
    raise Error.new("source payload byte count mismatch", code: "NOUS_UNSUPPORTED_SOURCE") unless payload_path.size == expected
  rescue ArgumentError, TypeError
    raise Error.new("source payload byte count is invalid", code: "NOUS_UNSUPPORTED_SOURCE")
  end

  def source_metadata_warnings(source)
    warnings = []
    warnings << { "code" => "NOUS_LEGACY_SOURCE_METADATA", "message" => "source sha256 is missing" } if string_value(source["sha256"]).empty?
    if source["bytes"].nil? || source["bytes"] == ""
      warnings << { "code" => "NOUS_LEGACY_SOURCE_METADATA", "message" => "source byte count is missing" }
    end
    warnings.first(2)
  end
end
