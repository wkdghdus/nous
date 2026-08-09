# frozen_string_literal: true

require "digest"
require "pathname"

module Nous
  module ArtifactIngestion
    SUPPORTED_EXTENSIONS = {
      "writing" => [".txt", ".md"],
      "image" => [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic"],
      "project" => [".txt", ".md", ".json", ".yaml", ".yml", ".jpg", ".jpeg", ".png", ".gif", ".webp"]
    }.freeze
    TEXT_EXTENSIONS = [".txt", ".md", ".json", ".yaml", ".yml"].freeze
    MAX_EXCERPT_CHARACTERS = 2_000
    RAW_DIRECTORIES = {
      "writing" => "writing",
      "image" => "images",
      "project" => "projects"
    }.freeze

    SourceMetadata = Struct.new(:payload_relative, :original_filename, :sha256, :bytes, keyword_init: true)

    module_function

    def ingest(source_path:, vault_root:, type:, date:, context: "", represented_date: nil, lock_timeout: nil, payload_validator: nil, before_commit: nil, after_finalize: nil, source_error_path: nil)
      source = validate_source(source_path, type, error_path: source_error_path)
      extension = source.extname
      text_content = text_like?(extension) ? read_text_content(source, error_path: source_error_path) : nil
      source_sha = digest_file(source)
      source_bytes = source.size
      slug = slug_for(source)
      root = prepare_vault_root(vault_root)

      VaultLock.new(vault_root: root, timeout: lock_timeout).with_exclusive do
        targets = destination_targets(root, type, date.to_s, slug, extension)
        payload_relative = targets.fetch(:payload_relative)
        artifact_relative = targets.fetch(:artifact_relative)
        artifact_id = File.basename(artifact_relative, ".md")
        draft_id = File.basename(targets.fetch(:draft_relative), ".md")
        source_metadata = SourceMetadata.new(
          payload_relative: payload_relative,
          original_filename: source.basename.to_s,
          sha256: source_sha,
          bytes: source_bytes
        )

        artifact = artifact_frontmatter(
          type: type,
          date: date.to_s,
          represented_date: represented_date,
          artifact_id: artifact_id,
          source_metadata: source_metadata
        )
        title = text_content ? title_from(text_content, slug) : "#{type.capitalize} Artifact"
        facts = text_content ? source_backed_facts(text_content) : "- Imported #{type} artifact metadata only."
        draft = draft_frontmatter(
          type: type,
          date: date.to_s,
          draft_id: draft_id,
          artifact_id: artifact_id,
          artifact_relative: artifact_relative
        )

        transaction = FileTransaction.new(vault_root: root)
        begin
          transaction.stage(
            path: payload_relative,
            source_path: source,
            validate: payload_validator || ->(temp_path) { verify_payload!(temp_path, source_sha, source_bytes) }
          )
          transaction.stage(path: artifact_relative, bytes: markdown_note(artifact, artifact_body(type, date.to_s, context, represented_date, source_metadata, text_content)))
          transaction.stage(path: targets.fetch(:draft_relative), bytes: markdown_note(draft, draft_body(type, date.to_s, context, represented_date, title, facts, source_metadata)))
          before_commit.call if before_commit
          transaction.commit(after_finalize: after_finalize)
        rescue StandardError
          transaction.rollback
          raise
        end

        {
          copied_source_path: payload_relative,
          artifact_path: artifact_relative,
          draft_path: targets.fetch(:draft_relative),
          artifact_id: artifact_id,
          draft_id: draft_id,
          sha256: source_sha,
          bytes: source_bytes
        }
      end
    end

    def prepare_vault_root(vault_root)
      root = Pathname(vault_root).expand_path
      if root.exist? && !root.directory?
        raise Error.new("vault root does not exist or is not a directory", code: "NOUS_VAULT_NOT_FOUND")
      end

      root.mkpath unless root.exist?
      root.realpath
    end

    def validate_source(path, type, error_path: nil)
      source = Pathname(path).expand_path
      display = error_path || source.basename.to_s
      unless SUPPORTED_EXTENSIONS.key?(type)
        raise Error.new("unsupported type: #{type}; expected writing, image, or project", code: "NOUS_UNSUPPORTED_SOURCE")
      end
      raise Error.new("source path does not exist: #{display}", code: "NOUS_UNSUPPORTED_SOURCE") unless source.exist?
      raise Error.new("symlinks are not supported: #{display}", code: "NOUS_UNSUPPORTED_SOURCE") if source.symlink?
      raise Error.new("source path is a directory: #{display}", code: "NOUS_UNSUPPORTED_SOURCE") if source.directory?
      raise Error.new("source path is not a regular file: #{display}", code: "NOUS_UNSUPPORTED_SOURCE") unless source.file?
      raise Error.new("hidden files are not supported: #{source.basename}", code: "NOUS_UNSUPPORTED_SOURCE") if source.basename.to_s.start_with?(".")

      extension = source.extname.downcase
      raise Error.new("unsupported source extension: (none)", code: "NOUS_UNSUPPORTED_SOURCE") if extension.empty?

      allowed = SUPPORTED_EXTENSIONS.fetch(type)
      return source if allowed.include?(extension)

      raise Error.new("unsupported source extension for #{type}: #{extension}; expected #{allowed.join(", ")}", code: "NOUS_UNSUPPORTED_SOURCE")
    rescue Errno::ENOENT
      raise Error.new("source path does not exist: #{display}", code: "NOUS_UNSUPPORTED_SOURCE")
    end

    def text_like?(extension)
      TEXT_EXTENSIONS.include?(extension.downcase)
    end

    def read_text_content(path, error_path: nil)
      display = error_path || path.basename.to_s
      content = path.binread
      content.force_encoding("UTF-8")
      raise Error.new("source file must be valid UTF-8: #{display}", code: "NOUS_UNSUPPORTED_SOURCE") unless content.valid_encoding?
      raise Error.new("source file is empty: #{display}", code: "NOUS_UNSUPPORTED_SOURCE") if content.strip.empty?

      content
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      raise Error.new("source file must be valid UTF-8: #{display}", code: "NOUS_UNSUPPORTED_SOURCE")
    end

    def slug_for(path)
      base = path.basename(path.extname).to_s.downcase
      slug = base.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-+\z/, "")
      slug.empty? ? "untitled" : slug
    end

    def digest_file(path)
      digest = Digest::SHA256.new
      File.open(path.to_s, "rb") do |file|
        buffer = +""
        digest.update(buffer) while file.read(1024 * 1024, buffer)
      end
      digest.hexdigest
    end

    def verify_payload!(path, expected_sha, expected_bytes)
      return if digest_file(path) == expected_sha && path.size == expected_bytes

      raise Error.new("copied payload failed checksum verification", code: "NOUS_WRITE_FAILED")
    end

    def destination_targets(vault_root, type, date, slug, extension)
      raw_directory = RAW_DIRECTORIES.fetch(type)
      index = 1
      loop do
        suffix = index == 1 ? "" : "-#{index}"
        payload_relative = "00_raw_artifacts/#{raw_directory}/files/#{slug}#{suffix}#{extension}"
        artifact_relative = "00_raw_artifacts/#{raw_directory}/notes/artifact_#{date}_#{slug}#{suffix}.md"
        draft_relative = "01_agent_inbox/notes/note_#{date}_#{slug}#{suffix}.md"
        paths = [payload_relative, artifact_relative, draft_relative].map do |relative|
          PathGuard.internal_path(vault_root: vault_root, path: relative, allow_missing: true, create_parent: true)
        end
        unless paths.any?(&:exist?)
          return {
            payload_relative: payload_relative,
            artifact_relative: artifact_relative,
            draft_relative: draft_relative
          }
        end

        index += 1
      end
    end

    def artifact_frontmatter(type:, date:, represented_date:, artifact_id:, source_metadata:)
      source = {
        "type" => type,
        "path" => source_metadata.payload_relative,
        "extraction_method" => "import",
        "original_filename" => source_metadata.original_filename,
        "sha256" => source_metadata.sha256,
        "bytes" => source_metadata.bytes
      }
      source["represented_date"] = represented_date.to_s unless represented_date.nil?

      {
        "id" => artifact_id,
        "type" => "artifact",
        "schema_version" => "0.1",
        "status" => "draft",
        "review_status" => "needs_review",
        "created" => date,
        "updated" => date,
        "source" => source,
        "interpretation_level" => "none",
        "tags" => []
      }
    end

    def draft_frontmatter(type:, date:, draft_id:, artifact_id:, artifact_relative:)
      {
        "id" => draft_id,
        "type" => "note",
        "schema_version" => "0.1",
        "status" => "draft",
        "review_status" => "agent_generated",
        "confidence" => 0.6,
        "created" => date,
        "updated" => date,
        "source" => {
          "type" => type,
          "path" => artifact_relative,
          "extraction_method" => "archivist_agent"
        },
        "interpretation_level" => "low",
        "evidence" => [{ "id" => artifact_id, "path" => artifact_relative }],
        "counterevidence" => [],
        "related" => [],
        "tags" => []
      }
    end

    def markdown_note(frontmatter, body)
      "---\n#{Nous.yaml_frontmatter(frontmatter)}---\n\n#{body}"
    end

    def source_metadata_lines(type, date, represented_date, source_metadata)
      [
        "- Copied source path: #{source_metadata.payload_relative}",
        "- Original filename: #{source_metadata.original_filename}",
        "- Source type: #{type}",
        "- Source SHA-256: #{source_metadata.sha256}",
        "- Source bytes: #{source_metadata.bytes}",
        "- Date represented: #{represented_date}",
        "- Import date: #{date}"
      ].join("\n")
    end

    def artifact_body(type, date, context, represented_date, source_metadata, text_content)
      observed = text_content ? source_excerpt(text_content) : ""

      <<~MARKDOWN
        # Artifact

        ## Source Metadata

        #{source_metadata_lines(type, date, represented_date, source_metadata)}

        ## Observed Content

        #{observed}

        ## User-Provided Context

        #{context.to_s.rstrip}

        ## Notes Created From This Artifact

        ## Review Notes
      MARKDOWN
    end

    def draft_body(type, date, context, represented_date, title, facts, source_metadata)
      <<~MARKDOWN
        # #{title}

        ## Source-Backed Facts

        #{facts}

        ## Source Metadata

        #{source_metadata_lines(type, date, represented_date, source_metadata)}

        ## User Context

        #{context.to_s.rstrip}

        ## Tentative Hypotheses

        ## Relationships

        ## Review Notes
      MARKDOWN
    end

    def title_from(content, fallback)
      first_line = content.each_line.map(&:strip).find { |line| !line.empty? }
      return fallback.split("-").map(&:capitalize).join(" ") if first_line.nil?

      first_line.sub(/\A#+\s*/, "")[0, 80]
    end

    def source_backed_facts(content)
      lines = content.each_line.map(&:strip).reject(&:empty?)
      facts = lines.first(3).map { |line| "- #{line[0, 160]}" }
      facts.empty? ? "- Source text contains no non-empty lines." : facts.join("\n")
    end

    def source_excerpt(content)
      content.rstrip[0, MAX_EXCERPT_CHARACTERS]
    end
  end
end
