# frozen_string_literal: true

require "pathname"

module Nous
  module RecordIndex
    MAX_DIAGNOSTICS = 50

    KNOWN_RECORD_DIRS = [
      "00_raw_artifacts/text",
      "00_raw_artifacts/writing/notes",
      "00_raw_artifacts/images/notes",
      "00_raw_artifacts/projects/notes",
      "01_agent_inbox/notes",
      "01_agent_inbox/claims",
      "01_agent_inbox/relationships",
      "02_notes/memories",
      "02_notes/values",
      "02_notes/beliefs",
      "02_notes/projects",
      "02_notes/patterns",
      "02_notes/decisions",
      "02_notes/people",
      "02_notes/questions",
      "02_notes/contradictions",
      "03_canonical_model/claims",
      "03_canonical_model/relationships"
    ].freeze

    NOTE_TYPE_BY_DIRECTORY = {
      "memories" => "memory",
      "values" => "value",
      "beliefs" => "belief",
      "projects" => "project",
      "patterns" => "pattern",
      "decisions" => "decision",
      "people" => "person",
      "questions" => "question",
      "contradictions" => "contradiction"
    }.freeze

    SCOPES = {
      "raw_evidence" => ["00_raw_artifacts/"],
      "inbox" => ["01_agent_inbox/"],
      "reviewed" => ["02_notes/"],
      "canonical" => ["03_canonical_model/"]
    }.freeze

    SUPPORTED_TYPES = (
      ["artifact", "note", "claim", "relationship"] + NOTE_TYPE_BY_DIRECTORY.values
    ).uniq.freeze

    IndexedRecord = Struct.new(:record, :id, :type, :kind, :lifecycle, :scope, keyword_init: true) do
      def relative_path
        record.relative_path
      end

      def frontmatter
        record.frontmatter
      end

      def body
        record.body
      end
    end

    Context = Struct.new(:vault_root, :records, :diagnostics, :duplicates, keyword_init: true) do
      def records_by_id
        @records_by_id ||= records.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, grouped|
          grouped[record.id] << record unless record.id.empty?
        end
      end

      def unique_record!(id)
        key = Nous.string_value(id)
        raise Error.new("record id is required", code: "NOUS_INVALID_INPUT") if key.empty?

        matches = records_by_id.fetch(key, [])
        raise Error.new("record not found", code: "NOUS_RECORD_NOT_FOUND") if matches.empty?
        if matches.length > 1
          raise Error.new("duplicate record id", code: "NOUS_DUPLICATE_ID", details: { id: key, count: matches.length })
        end

        matches.first
      end
    end

    module_function

    def scan(vault_root:, scopes: SCOPES.keys, permitted_classes: [])
      scan_internal(vault_root: vault_root, scopes: scopes, strict: false, permitted_classes: permitted_classes)
    end

    def scan!(vault_root:, scopes: SCOPES.keys, permitted_classes: [])
      scan_internal(vault_root: vault_root, scopes: scopes, strict: true, permitted_classes: permitted_classes)
    end

    def scan_internal(vault_root:, scopes:, strict:, permitted_classes: [])
      root = PathGuard.validate_vault_root(vault_root)
      selected_dirs = directories_for_scopes(scopes)
      diagnostics = []
      records = []

      selected_dirs.each do |relative_dir|
        dir = root + relative_dir
        status = known_directory_status(root, relative_dir)
        case status
        when :missing
          next
        when :symlink
          handle_problem!(diagnostics, strict, "symlinked record directory rejected", "NOUS_SYMLINK_REJECTED", relative_dir)
          next
        when :not_directory
          handle_problem!(diagnostics, strict, "known record path is not a directory", "NOUS_INVALID_INPUT", relative_dir)
          next
        end

        dir.children.sort_by { |path| path.basename.to_s }.each do |path|
          basename = path.basename.to_s
          next if basename == "AGENT.md"
          next unless path.extname == ".md" || path.symlink?

          relative = "#{relative_dir}/#{basename}"
          if path.symlink?
            handle_problem!(diagnostics, strict, "symlinked record file rejected", "NOUS_SYMLINK_REJECTED", relative)
            next
          end
          next unless path.file? && path.extname == ".md"

          begin
            real = PathGuard.internal_path(vault_root: root, path: relative)
            frontmatter, body = Nous.parse_markdown(real, permitted_classes: permitted_classes, error_path: relative)
            indexed = indexed_record(path: real, relative_path: relative, frontmatter: frontmatter, body: body)
            records << indexed unless indexed.nil?
          rescue Nous::Error => error
            handle_problem!(diagnostics, strict, error.message, error.code, relative)
          end
        end
      end

      records.sort_by! { |record| [record.id, record.relative_path] }
      duplicates = duplicate_groups(records)
      add_duplicate_diagnostics(diagnostics, duplicates)
      Context.new(vault_root: root, records: records, diagnostics: diagnostics.first(MAX_DIAGNOSTICS), duplicates: duplicates)
    end

    def directories_for_scopes(scopes)
      normalized = Array(scopes || SCOPES.keys).map { |scope| Nous.string_value(scope) }
      invalid = normalized - SCOPES.keys
      unless invalid.empty?
        raise Error.new("unsupported record scope", code: "NOUS_INVALID_INPUT", details: { scopes: invalid })
      end

      KNOWN_RECORD_DIRS.select do |directory|
        normalized.any? do |scope|
          SCOPES.fetch(scope).any? { |prefix| directory.start_with?(prefix) }
        end
      end
    end

    def known_directory_status(root, relative_dir)
      current = root
      relative_dir.split("/").each do |part|
        current += part
        return :symlink if current.symlink?
        return :missing unless current.exist?
      end
      return :not_directory unless current.directory?

      :ok
    end

    def indexed_record(path:, relative_path:, frontmatter:, body:)
      classification = classify(relative_path, frontmatter)
      return nil if classification.nil?

      validate_frontmatter!(relative_path, frontmatter, classification)
      id = Nous.string_value(frontmatter["id"])
      type = classification.fetch(:type)
      record = Nous::Record.new(
        path: path,
        relative_path: relative_path,
        frontmatter: frontmatter,
        body: body,
        record_kind: classification.fetch(:kind)
      )
      IndexedRecord.new(
        record: record,
        id: id,
        type: type,
        kind: classification.fetch(:kind),
        lifecycle: lifecycle_for(relative_path, frontmatter),
        scope: classification.fetch(:scope)
      )
    end

    def classify(relative_path, frontmatter)
      parts = relative_path.split("/")
      if relative_path.start_with?("00_raw_artifacts/text/") ||
         relative_path.start_with?("00_raw_artifacts/writing/notes/") ||
         relative_path.start_with?("00_raw_artifacts/images/notes/") ||
         relative_path.start_with?("00_raw_artifacts/projects/notes/")
        return { kind: "artifact", type: "artifact", scope: "raw_evidence" }
      end

      return { kind: "note", type: "note", scope: "inbox" } if relative_path.start_with?("01_agent_inbox/notes/")
      return { kind: "claim", type: "claim", scope: "inbox" } if relative_path.start_with?("01_agent_inbox/claims/")
      return { kind: "relationship", type: "relationship", scope: "inbox" } if relative_path.start_with?("01_agent_inbox/relationships/")

      if parts.length == 3 && parts[0] == "02_notes"
        type = NOTE_TYPE_BY_DIRECTORY.fetch(parts[1], nil)
        return { kind: type, type: type, scope: "reviewed" } unless type.nil?
      end

      return { kind: "claim", type: "claim", scope: "canonical" } if relative_path.start_with?("03_canonical_model/claims/")
      return { kind: "relationship", type: "relationship", scope: "canonical" } if relative_path.start_with?("03_canonical_model/relationships/")

      nil
    end

    def validate_frontmatter!(relative_path, frontmatter, classification)
      if Nous.string_value(frontmatter["id"]).empty?
        raise Error.new("missing record id: #{relative_path}", code: "NOUS_INVALID_INPUT")
      end

      frontmatter_type = Nous.string_value(frontmatter["type"])
      if frontmatter_type.empty?
        raise Error.new("missing record type: #{relative_path}", code: "NOUS_INVALID_INPUT")
      end

      expected = classification.fetch(:type)
      return if classification.fetch(:scope) == "inbox" && expected == "note"
      return if frontmatter_type == expected

      raise Error.new("record type #{frontmatter_type.inspect} does not match #{expected.inspect}: #{relative_path}", code: "NOUS_UNSUPPORTED_RECORD_TYPE")
    end

    def lifecycle_for(relative_path, frontmatter)
      return "retired" if retired?(frontmatter)
      return "source_evidence" if relative_path.start_with?("00_raw_artifacts/")
      return "agent_candidate" if relative_path.start_with?("01_agent_inbox/")
      return "human_reviewed" if relative_path.start_with?("02_notes/") && active_reviewed?(frontmatter)
      return "canonical" if relative_path.start_with?("03_canonical_model/") && active_reviewed?(frontmatter)

      "retired"
    end

    def retired?(frontmatter)
      status = Nous.string_value(frontmatter["status"])
      review_status = Nous.string_value(frontmatter["review_status"])
      decision = Nous.string_value(frontmatter["review_decision"])
      status == "archived" || %w[rejected deprecated].include?(review_status) || decision == "merged"
    end

    def active_reviewed?(frontmatter)
      Nous.string_value(frontmatter["status"]) == "active" && Nous.string_value(frontmatter["review_status"]) == "reviewed"
    end

    def duplicate_groups(records)
      records.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, grouped|
        grouped[record.id] << record.relative_path unless record.id.empty?
      end.select { |_id, paths| paths.length > 1 }
    end

    def add_duplicate_diagnostics(diagnostics, duplicates)
      duplicates.sort.each do |id, paths|
        add_diagnostic(diagnostics, "NOUS_DUPLICATE_ID", "duplicate record id", paths.first, id: id, count: paths.length)
      end
    end

    def handle_problem!(diagnostics, strict, message, code, relative_path)
      sanitized = sanitize_message(message, relative_path)
      if strict
        raise Error.new(sanitized, code: code, details: { path: relative_path })
      end

      add_diagnostic(diagnostics, code, sanitized, relative_path)
    end

    def add_diagnostic(diagnostics, code, message, relative_path, extra = {})
      return if diagnostics.length >= MAX_DIAGNOSTICS

      diagnostics << { "code" => code, "message" => message, "path" => relative_path }.merge(stringify_keys(extra))
    end

    def stringify_keys(hash)
      hash.each_with_object({}) { |(key, value), out| out[key.to_s] = value }
    end

    def sanitize_message(message, relative_path)
      text = message.to_s
      return text if relative_path.nil? || relative_path.empty?

      # Parser errors are invoked with vault-relative error paths. If a lower layer
      # still exposes local context, collapse it to a stable relative-path message.
      if text.include?(relative_path)
        text
      else
        "#{text}: #{relative_path}"
      end
    end
  end
end
