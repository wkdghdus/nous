# frozen_string_literal: true

require "fileutils"
require "time"

module Nous
  module ReviewMutation
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
    MERGE_TARGET_PREFIXES = ["02_notes/", "03_canonical_model/"].freeze
    MERGE_TARGET_ERROR = "merge target must be inside vault/02_notes or vault/03_canonical_model"

    module_function

    def approve(path:, vault_root:, timestamp:, note_type: nil, reviewer_note: nil, after_stage: nil)
      root = PathGuard.validate_vault_root(vault_root)
      VaultLock.new(vault_root: root).with_exclusive do
        item = load_item(path, vault_root: root)
        require_pending!(item)
        destination = approval_destination(item, root, note_type)
        if destination.exist?
          raise Error.new("destination already exists: #{PathGuard.relative_path(vault_root: root, path: destination)}", code: "NOUS_WRITE_FAILED")
        end

        RelationshipIntegrity.validate_relationship!(vault_root: root, item: item) if item.kind == "relationship"
        frontmatter = item.frontmatter.dup
        frontmatter["type"] = note_type if item.kind == "note"
        apply_decision(frontmatter, "approved", timestamp, status: "active", review_status: "reviewed", note: reviewer_note)
        bytes = markdown(frontmatter, item.body)

        source_bytes = item.path.binread
        destination_relative = PathGuard.relative_path(vault_root: root, path: destination)
        begin
          PathGuard.internal_path(vault_root: root, path: destination_relative, allow_missing: true, create_parent: true)
          destination.dirname.mkpath
          replace_existing(root, item.path, bytes)
          after_stage.call if after_stage
          if destination.exist?
            raise Error.new("destination already exists: #{destination_relative}", code: "NOUS_WRITE_FAILED")
          end
          File.rename(item.path.to_s, destination.to_s)
        rescue Error
          restore_approved_source(root, item, source_bytes, destination)
          raise
        rescue SystemCallError
          restore_approved_source(root, item, source_bytes, destination)
          raise Error.new("failed to finalize import", code: "NOUS_WRITE_FAILED")
        rescue StandardError
          restore_approved_source(root, item, source_bytes, destination)
          raise
        end

        {
          decision: "approved",
          source_path: item.relative_path,
          destination_path: PathGuard.relative_path(vault_root: root, path: destination)
        }
      end
    end

    def reject(path:, vault_root:, timestamp:, reviewer_note: nil, decision: "rejected", after_replace: nil)
      root = PathGuard.validate_vault_root(vault_root)
      VaultLock.new(vault_root: root).with_exclusive do
        item = load_item(path, vault_root: root)
        require_pending!(item)
        review_status = decision == "deprecated" ? "deprecated" : "rejected"
        frontmatter = item.frontmatter.dup
        apply_decision(frontmatter, decision, timestamp, status: "archived", review_status: review_status, note: reviewer_note)
        replace_existing(root, item.path, markdown(frontmatter, item.body))
        after_replace.call if after_replace
        { decision: decision, source_path: item.relative_path }
      end
    end

    def deprecate(path:, vault_root:, timestamp:, reviewer_note: nil)
      reject(path: path, vault_root: vault_root, timestamp: timestamp, reviewer_note: reviewer_note, decision: "deprecated")
    end

    def merge(path:, vault_root:, target_path:, timestamp:, reviewer_note: nil, after_first_replace: nil)
      root = PathGuard.validate_vault_root(vault_root)
      VaultLock.new(vault_root: root).with_exclusive do
        item = load_item(path, vault_root: root)
        require_pending!(item)
        target = resolve_merge_target(target_path, root)
        validate_merge_target!(target, root)
        target_relative = PathGuard.relative_path(vault_root: root, path: target)
        target_frontmatter, target_body = Nous.parse_markdown(target, error_path: target_relative)

        source_reference = { "id" => item.frontmatter["id"].to_s, "path" => item.relative_path }
        target_frontmatter = target_frontmatter.dup
        target_frontmatter["evidence"] = uniq_evidence(evidence_entries(target_frontmatter) + evidence_entries(item.frontmatter) + [source_reference])
        target_frontmatter["updated"] = review_date(timestamp)

        source_frontmatter = item.frontmatter.dup
        apply_decision(
          source_frontmatter,
          "merged",
          timestamp,
          status: "archived",
          review_status: "reviewed",
          note: reviewer_note,
          merged_into: target_relative
        )

        originals = {
          target => target.binread,
          item.path => item.path.binread
        }
        begin
          replace_existing(root, target, markdown(target_frontmatter, target_body))
          after_first_replace.call if after_first_replace
          replace_existing(root, item.path, markdown(source_frontmatter, item.body))
        rescue StandardError
          restore_originals(root, originals)
          raise
        end

        { decision: "merged", source_path: item.relative_path, target_path: target_relative }
      end
    end

    def resolve_for_edit(path:, vault_root:)
      root = PathGuard.validate_vault_root(vault_root)
      item = load_item(path, vault_root: root)
      { path: item.path, relative_path: item.relative_path }
    end

    def load_item(path, vault_root:)
      root = PathGuard.validate_vault_root(vault_root)
      resolved = resolve_existing_path(path, root)
      kind = kind_for_path(resolved, root)
      if kind.nil?
        raise Error.new("path is not in a review inbox: #{Nous.relative_or_absolute(resolved, root)}", code: "NOUS_INVALID_INPUT")
      end

      relative = PathGuard.relative_path(vault_root: root, path: resolved)
      frontmatter, body = Nous.parse_markdown(resolved, error_path: relative)
      ReviewItem.new(path: resolved, relative_path: relative, kind: kind, frontmatter: frontmatter, body: body)
    rescue Errno::ENOENT
      raise Error.new("review item does not exist", code: "NOUS_RECORD_NOT_FOUND")
    end

    def resolve_existing_path(value, vault_root)
      path = Pathname(value)
      candidate = path.absolute? ? path.expand_path : (vault_root + value).expand_path
      unless candidate.file?
        raise Error.new("review item does not exist", code: "NOUS_RECORD_NOT_FOUND")
      end

      PathGuard.internal_path(vault_root: vault_root, path: candidate)
    end

    def resolve_merge_target(value, vault_root)
      path = Pathname(value)
      candidate = path.absolute? ? path.expand_path : (vault_root + value).expand_path
      unless candidate.file?
        raise Error.new("merge target does not exist", code: "NOUS_RECORD_NOT_FOUND")
      end
      unless candidate.extname == ".md" && candidate.basename.to_s != "AGENT.md"
        raise Error.new("merge target must be a Markdown reviewed or canonical record", code: "NOUS_INVALID_INPUT")
      end

      relative = candidate.realpath.relative_path_from(vault_root.realpath).to_s
      unless MERGE_TARGET_PREFIXES.any? { |prefix| relative.start_with?(prefix) }
        raise Error.new(MERGE_TARGET_ERROR, code: "NOUS_INVALID_INPUT")
      end

      PathGuard.internal_path(vault_root: vault_root, path: candidate)
    rescue ArgumentError
      raise Error.new(MERGE_TARGET_ERROR, code: "NOUS_INVALID_INPUT")
    end

    def kind_for_path(path, vault_root)
      relative = PathGuard.relative_path(vault_root: vault_root, path: path)
      INBOX_DIRS.each do |kind, directory|
        return kind if relative.start_with?("#{directory}/")
      end

      nil
    end

    def require_pending!(item)
      return if PENDING_REVIEW_STATUSES.include?(item.review_status) && item.frontmatter["status"].to_s != "archived"

      raise Error.new("path is not pending review: #{item.relative_path}", code: "NOUS_REVIEW_REQUIRED")
    end

    def approval_destination(item, vault_root, note_type)
      case item.kind
      when "note"
        if note_type.nil? || note_type.empty?
          raise Error.new("approving an inbox note requires --as TYPE", code: "NOUS_INVALID_INPUT")
        end
        unless NOTE_TYPE_DIRS.key?(note_type)
          raise Error.new("unsupported note type: #{note_type}; expected one of #{NOTE_TYPE_DIRS.keys.join(", ")}", code: "NOUS_INVALID_INPUT")
        end

        vault_root + "02_notes/#{NOTE_TYPE_DIRS.fetch(note_type)}/#{item.path.basename}"
      when "claim"
        vault_root + "03_canonical_model/claims/#{item.path.basename}"
      when "relationship"
        vault_root + "03_canonical_model/relationships/#{item.path.basename}"
      else
        raise Error.new("unsupported item kind: #{item.kind}", code: "NOUS_INVALID_INPUT")
      end
    end

    def validate_merge_target!(target, vault_root)
      unless target.extname == ".md" && target.basename.to_s != "AGENT.md"
        raise Error.new("merge target must be a Markdown reviewed or canonical record", code: "NOUS_INVALID_INPUT")
      end

      relative = PathGuard.relative_path(vault_root: vault_root, path: target)
      unless MERGE_TARGET_PREFIXES.any? { |prefix| relative.start_with?(prefix) }
        raise Error.new(MERGE_TARGET_ERROR, code: "NOUS_INVALID_INPUT")
      end
    end

    def review_date(timestamp)
      Time.iso8601(timestamp).utc.strftime("%Y-%m-%d")
    end

    def review_metadata(decision, timestamp, note: nil, merged_into: nil)
      metadata = { "decision" => decision, "decided_at" => timestamp }
      metadata["reviewer_note"] = note unless note.nil? || note.empty?
      metadata["merged_into"] = merged_into unless merged_into.nil? || merged_into.empty?
      metadata
    end

    def apply_decision(frontmatter, decision, timestamp, status:, review_status:, note: nil, merged_into: nil)
      frontmatter["status"] = status
      frontmatter["review_status"] = review_status
      frontmatter["updated"] = review_date(timestamp)
      existing = frontmatter["review"].is_a?(Hash) ? frontmatter["review"] : {}
      frontmatter["review"] = existing.merge(review_metadata(decision, timestamp, note: note, merged_into: merged_into))
    end

    def evidence_entries(frontmatter)
      evidence = frontmatter["evidence"]
      return [] unless evidence.is_a?(Array)

      evidence.select { |entry| entry.is_a?(Hash) && entry["path"] }
    end

    def uniq_evidence(entries)
      seen = {}
      entries.each_with_object([]) do |entry, unique|
        key = [entry["id"].to_s, entry["path"].to_s]
        next if seen[key]

        seen[key] = true
        unique << entry
      end
    end

    def markdown(frontmatter, body)
      "---\n#{Nous.yaml_frontmatter(frontmatter)}---\n#{body.start_with?("\n") ? body : "\n#{body}"}"
    end

    def replace_existing(vault_root, path, bytes)
      relative = PathGuard.relative_path(vault_root: vault_root, path: path)
      AtomicWriter.replace(vault_root: vault_root, path: relative, bytes: bytes)
    end

    def restore_originals(vault_root, originals)
      originals.each do |path, bytes|
        replace_existing(vault_root, path, bytes)
      end
    end

    def restore_approved_source(vault_root, item, bytes, destination)
      FileUtils.rm_f(destination.to_s) if destination.exist? && !item.path.exist?
      if item.path.exist?
        replace_existing(vault_root, item.path, bytes)
      else
        AtomicWriter.create(vault_root: vault_root, path: item.relative_path, bytes: bytes)
      end
    end
  end
end
