# frozen_string_literal: true

module Nous
  module RelationshipIntegrity
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
    NOTE_TYPE_DIRS = {
      "memory" => "memories",
      "value" => "values",
      "belief" => "beliefs",
      "project" => "projects",
      "pattern" => "patterns",
      "decision" => "decisions",
      "person" => "people",
      "question" => "questions",
      "contradiction" => "contradictions"
    }.freeze

    module_function

    def validate_relationship!(vault_root:, item:)
      relationship = item.frontmatter["relationship"]
      unless relationship.is_a?(Hash)
        raise Error.new("missing relationship mapping: #{item.relative_path}", code: "NOUS_INVALID_INPUT")
      end

      endpoint_ids = %w[from to].map do |field|
        value = Nous.string_value(relationship[field])
        raise Error.new("missing relationship.#{field}: #{item.relative_path}", code: "NOUS_INVALID_INPUT") if value.empty?

        value
      end

      index = records_by_id(vault_root)
      failures = endpoint_ids.each_with_object([]) do |id, list|
        records = index.fetch(id, [])
        if records.empty?
          list << "#{id}: missing"
        elsif records.length > 1
          raise Error.new("duplicate endpoint id #{id.inspect}", code: "NOUS_DUPLICATE_ID")
        elsif !eligible_endpoint?(records.first)
          list << "#{id}: #{lifecycle_for(records.first)}"
        end
      end

      return true if failures.empty?

      raise Error.new("relationship endpoints require active reviewed note or canonical claim: #{failures.join(", ")}", code: "NOUS_REVIEW_REQUIRED")
    end

    def records_by_id(vault_root)
      root = PathGuard.validate_vault_root(vault_root)
      KNOWN_RECORD_DIRS.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |directory, grouped|
        dir = root + directory
        next unless dir.directory?

        Nous.markdown_files(dir).each do |path|
          relative = PathGuard.relative_path(vault_root: root, path: path)
          frontmatter, body = Nous.parse_markdown(path, error_path: relative)
          id = Nous.string_value(frontmatter["id"])
          next if id.empty?

          grouped[id] << Nous::Record.new(
            path: path,
            relative_path: relative,
            frontmatter: frontmatter,
            body: body,
            record_kind: Nous.record_kind_for(relative)
          )
        end
      end
    end

    def eligible_endpoint?(record)
      return false unless active_reviewed?(record)
      return true if reviewed_note?(record)
      return true if canonical_claim?(record)

      false
    end

    def active_reviewed?(record)
      Nous.string_value(record.frontmatter["status"]) == "active" &&
        Nous.string_value(record.frontmatter["review_status"]) == "reviewed"
    end

    def reviewed_note?(record)
      parts = record.relative_path.split("/")
      return false unless parts.length == 3 && parts[0] == "02_notes"

      NOTE_TYPE_DIRS.any? do |type, directory|
        parts[1] == directory && Nous.string_value(record.frontmatter["type"]) == type
      end
    end

    def canonical_claim?(record)
      record.relative_path.start_with?("03_canonical_model/claims/") &&
        Nous.string_value(record.frontmatter["type"]) == "claim"
    end

    def lifecycle_for(record)
      return "retired" if Nous.string_value(record.frontmatter["status"]) == "archived"
      return "source_evidence" if record.relative_path.start_with?("00_raw_artifacts/")
      return "agent_candidate" if record.relative_path.start_with?("01_agent_inbox/")
      return "relationship" if record.relative_path.start_with?("03_canonical_model/relationships/")
      return "human_reviewed" if record.relative_path.start_with?("02_notes/")
      return "canonical" if record.relative_path.start_with?("03_canonical_model/")

      "unsupported"
    end
  end
end
