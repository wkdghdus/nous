# frozen_string_literal: true

require "pathname"

module Nous
  module TextIngestion
    SUPPORTED_EXTENSIONS = [".txt", ".md"].freeze

    module_function

    def ingest(source_path:, vault_root:, date:, source_display_base: nil, before_commit: nil, source_error_path: nil)
      root = prepare_vault_root(vault_root)
      source = validate_source(source_path, error_path: source_error_path)
      content = read_source(source, error_path: source_error_path)
      slug = slug_for(source)
      import_date = date.to_s

      VaultLock.new(vault_root: root).with_exclusive do
        artifact = CollisionAllocator.next_available_path(
          vault_root: root,
          directory: "00_raw_artifacts/text",
          basename: "artifact_#{import_date}_#{slug}"
        )
        draft = CollisionAllocator.next_available_path(
          vault_root: root,
          directory: "01_agent_inbox/notes",
          basename: "note_#{import_date}_#{slug}"
        )

        artifact_bytes = render_note(
          artifact_frontmatter(
            id: artifact.fetch(:id),
            source_path: display_source_path(source, source_display_base),
            date: import_date
          ),
          artifact_body(source, source_display_base, content, import_date)
        )
        draft_bytes = render_note(
          draft_frontmatter(
            id: draft.fetch(:id),
            artifact_id: artifact.fetch(:id),
            artifact_path: artifact.fetch(:relative_path),
            date: import_date
          ),
          draft_body(title_from(content, slug), source_backed_facts(content))
        )

        transaction = FileTransaction.new(vault_root: root)
        begin
          transaction.stage(path: artifact.fetch(:relative_path), bytes: artifact_bytes)
          transaction.stage(path: draft.fetch(:relative_path), bytes: draft_bytes)
          before_commit.call if before_commit
          transaction.commit
        rescue StandardError
          transaction.rollback
          raise
        end

        {
          artifact_id: artifact.fetch(:id),
          draft_id: draft.fetch(:id),
          artifact_path: artifact.fetch(:relative_path),
          draft_path: draft.fetch(:relative_path)
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

    def validate_source(path, error_path: nil)
      source = Pathname(path).expand_path
      display = error_path || source.basename.to_s
      raise Error.new("source path does not exist: #{display}", code: "NOUS_UNSUPPORTED_SOURCE") unless source.exist?
      raise Error.new("source path is a directory: #{display}", code: "NOUS_UNSUPPORTED_SOURCE") if source.directory?

      extension = source.extname.downcase
      unless SUPPORTED_EXTENSIONS.include?(extension)
        raise Error.new("unsupported source extension: #{extension.empty? ? "(none)" : extension}", code: "NOUS_UNSUPPORTED_SOURCE")
      end

      PathGuard.operator_source(source)
    rescue Errno::ENOENT
      raise Error.new("source path does not exist: #{display}", code: "NOUS_UNSUPPORTED_SOURCE")
    end

    def read_source(source, error_path: nil)
      display = error_path || source.basename.to_s
      content = source.binread
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

    def display_source_path(source, base)
      return source.to_s if base.nil?

      source.relative_path_from(Pathname(base).expand_path).to_s.then do |relative|
        relative.start_with?("..") ? source.to_s : relative
      end
    rescue ArgumentError
      source.to_s
    end

    def artifact_frontmatter(id:, source_path:, date:)
      {
        "id" => id,
        "type" => "artifact",
        "schema_version" => "0.1",
        "status" => "draft",
        "review_status" => "needs_review",
        "created" => date,
        "updated" => date,
        "source" => {
          "type" => "text",
          "path" => source_path,
          "extraction_method" => "import"
        },
        "interpretation_level" => "none",
        "tags" => []
      }
    end

    def draft_frontmatter(id:, artifact_id:, artifact_path:, date:)
      {
        "id" => id,
        "type" => "note",
        "schema_version" => "0.1",
        "status" => "draft",
        "review_status" => "agent_generated",
        "confidence" => 0.6,
        "created" => date,
        "updated" => date,
        "source" => {
          "type" => "text",
          "path" => artifact_path,
          "extraction_method" => "archivist_agent"
        },
        "interpretation_level" => "low",
        "evidence" => [
          {
            "id" => artifact_id,
            "path" => artifact_path
          }
        ],
        "counterevidence" => [],
        "related" => [],
        "tags" => []
      }
    end

    def render_note(frontmatter, body)
      "---\n#{Nous.yaml_frontmatter(frontmatter)}---\n\n#{body}"
    end

    def artifact_body(source_path, source_display_base, content, import_date)
      source = display_source_path(Pathname(source_path).expand_path, source_display_base)

      <<~MARKDOWN
        # Artifact

        ## Source Metadata

        - Source path: #{source}
        - Source type: text
        - Date represented:
        - Import date: #{import_date}

        ## Observed Content

        #{content.rstrip}

        ## User-Provided Context

        ## Notes Created From This Artifact

        ## Review Notes
      MARKDOWN
    end

    def draft_body(title, facts)
      <<~MARKDOWN
        # #{title}

        ## Source-Backed Facts

        #{facts}

        ## User Context

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
  end
end
