#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "fileutils"
require "optparse"
require "pathname"
require "psych"
require "securerandom"

ROOT = Pathname(__dir__).parent.expand_path
DEFAULT_VAULT_ROOT = ROOT + "vault"
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

class IngestArtifactError < StandardError; end

Options = Struct.new(:source_path, :vault_root, :today, :type, :context, :represented_date, keyword_init: true)
Targets = Struct.new(:payload, :artifact, :draft, keyword_init: true)
SourceMetadata = Struct.new(:payload_relative, :original_filename, :sha256, :bytes, keyword_init: true)

def parse_options(argv)
  options = Options.new(vault_root: DEFAULT_VAULT_ROOT, today: ENV["NOUS_INGEST_DATE"], context: "")

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/ingest_artifact.rb --type writing|image|project [options] SOURCE_PATH"
    opts.on("--type TYPE", "Artifact type: writing, image, or project.") { |type| options.type = type }
    opts.on("--vault-root PATH", "Vault root to write into. Defaults to ./vault.") do |path|
      options.vault_root = Pathname(path).expand_path
    end
    opts.on("--date YYYY-MM-DD", "Import date. Defaults to today.") { |date| options.today = date }
    opts.on("--represented-date YYYY-MM-DD", "Date represented by the source.") do |date|
      options.represented_date = date
    end
    opts.on("--context TEXT", "User-provided source context.") { |context| options.context = context }
    opts.on("-h", "--help", "Show this help.") do
      puts opts
      exit 0
    end
  end

  parser.parse!(argv)
  raise IngestArtifactError, "expected exactly one source path" unless argv.length == 1

  options.type = validate_type(options.type)
  options.today = parse_date(options.today, "date")
  options.represented_date = parse_date(options.represented_date, "represented-date") unless blank?(options.represented_date)
  options.source_path = Pathname(argv.first).expand_path
  options
rescue OptionParser::ParseError => error
  raise IngestArtifactError, error.message
end

def validate_type(type)
  raise IngestArtifactError, "type is required; use --type writing|image|project" if blank?(type)

  normalized = type.downcase
  return normalized if SUPPORTED_EXTENSIONS.key?(normalized)

  raise IngestArtifactError, "unsupported type: #{type}; expected writing, image, or project"
end

def parse_date(value, label)
  return Date.today if blank?(value) && label == "date"

  Date.iso8601(value)
rescue Date::Error, TypeError
  raise IngestArtifactError, "#{label} must use YYYY-MM-DD"
end

def blank?(value)
  value.nil? || value.to_s.empty?
end

def validate_source(path, type)
  raise IngestArtifactError, "source path does not exist: #{path}" unless path.exist?
  raise IngestArtifactError, "symlinks are not supported: #{path}" if path.symlink?
  raise IngestArtifactError, "source path is a directory: #{path}" if path.directory?
  raise IngestArtifactError, "source path is not a regular file: #{path}" unless path.file?
  raise IngestArtifactError, "hidden files are not supported: #{path.basename}" if path.basename.to_s.start_with?(".")

  extension = path.extname.downcase
  raise IngestArtifactError, "unsupported source extension: (none)" if extension.empty?

  allowed = SUPPORTED_EXTENSIONS.fetch(type)
  return extension if allowed.include?(extension)

  raise IngestArtifactError, "unsupported source extension for #{type}: #{extension}; expected #{allowed.join(", ")}"
rescue Errno::ENOENT
  raise IngestArtifactError, "source path does not exist: #{path}"
end

def text_like?(extension)
  TEXT_EXTENSIONS.include?(extension)
end

def read_text_content(path)
  content = path.binread
  content.force_encoding("UTF-8")
  raise IngestArtifactError, "source file must be valid UTF-8: #{path}" unless content.valid_encoding?
  raise IngestArtifactError, "source file is empty: #{path}" if content.strip.empty?

  content
rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
  raise IngestArtifactError, "source file must be valid UTF-8: #{path}"
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

def yaml_frontmatter(data)
  Psych.dump(data).sub(/\A---\n/, "")
end

def markdown_note(frontmatter, body)
  "---\n#{yaml_frontmatter(frontmatter)}---\n\n#{body}"
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

def vault_relative(path, vault_root)
  path.expand_path.relative_path_from(vault_root.expand_path).to_s
end

def destination_targets(options, slug, extension)
  raw_directory = RAW_DIRECTORIES.fetch(options.type)
  payload_dir = options.vault_root + "00_raw_artifacts/#{raw_directory}/files"
  artifact_dir = options.vault_root + "00_raw_artifacts/#{raw_directory}/notes"
  draft_dir = options.vault_root + "01_agent_inbox/notes"
  date = options.today.to_s

  index = 1
  loop do
    suffix = index == 1 ? "" : "-#{index}"
    targets = Targets.new(
      payload: payload_dir + "#{slug}#{suffix}#{extension}",
      artifact: artifact_dir + "artifact_#{date}_#{slug}#{suffix}.md",
      draft: draft_dir + "note_#{date}_#{slug}#{suffix}.md"
    )
    return targets unless [targets.payload, targets.artifact, targets.draft].any?(&:exist?)

    index += 1
  end
end

def artifact_frontmatter(options, artifact_id, source_metadata)
  source = {
    "type" => options.type,
    "path" => source_metadata.payload_relative,
    "extraction_method" => "import",
    "original_filename" => source_metadata.original_filename,
    "sha256" => source_metadata.sha256,
    "bytes" => source_metadata.bytes
  }
  source["represented_date"] = options.represented_date.to_s unless options.represented_date.nil?

  {
    "id" => artifact_id,
    "type" => "artifact",
    "schema_version" => "0.1",
    "status" => "draft",
    "review_status" => "needs_review",
    "created" => options.today.to_s,
    "updated" => options.today.to_s,
    "source" => source,
    "interpretation_level" => "none",
    "tags" => []
  }
end

def draft_frontmatter(options, draft_id, artifact_id, artifact_relative)
  {
    "id" => draft_id,
    "type" => "note",
    "schema_version" => "0.1",
    "status" => "draft",
    "review_status" => "agent_generated",
    "confidence" => 0.6,
    "created" => options.today.to_s,
    "updated" => options.today.to_s,
    "source" => {
      "type" => options.type,
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

def source_metadata_lines(options, source_metadata)
  represented = options.represented_date&.to_s

  [
    "- Copied source path: #{source_metadata.payload_relative}",
    "- Original filename: #{source_metadata.original_filename}",
    "- Source type: #{options.type}",
    "- Source SHA-256: #{source_metadata.sha256}",
    "- Source bytes: #{source_metadata.bytes}",
    "- Date represented: #{represented}",
    "- Import date: #{options.today}"
  ].join("\n")
end

def artifact_body(options, source_metadata, text_content)
  observed = text_content ? source_excerpt(text_content) : ""

  <<~MARKDOWN
    # Artifact

    ## Source Metadata

    #{source_metadata_lines(options, source_metadata)}

    ## Observed Content

    #{observed}

    ## User-Provided Context

    #{options.context.to_s.rstrip}

    ## Notes Created From This Artifact

    ## Review Notes
  MARKDOWN
end

def draft_body(options, title, facts, source_metadata)
  <<~MARKDOWN
    # #{title}

    ## Source-Backed Facts

    #{facts}

    ## Source Metadata

    #{source_metadata_lines(options, source_metadata)}

    ## User Context

    #{options.context.to_s.rstrip}

    ## Tentative Hypotheses

    ## Relationships

    ## Review Notes
  MARKDOWN
end

def staged_path(final_path)
  final_path.dirname + ".#{final_path.basename}.tmp-#{Process.pid}-#{SecureRandom.hex(8)}"
end

def cleanup(paths)
  paths.compact.each do |path|
    FileUtils.rm_f(path.to_s) if path.exist? || path.symlink?
  end
end

def write_staged(path, content)
  path.dirname.mkpath
  path.binwrite(content)
rescue SystemCallError => error
  raise IngestArtifactError, "failed to finalize import: #{error.message}"
end

def finalize!(staged, final, created)
  raise IngestArtifactError, "destination already exists: #{final}" if final.exist?

  final.dirname.mkpath
  FileUtils.mv(staged.to_s, final.to_s)
  created << final
rescue SystemCallError => error
  raise IngestArtifactError, "failed to finalize import: #{error.message}"
end

def ingest(options)
  staged = []
  created = []
  extension = validate_source(options.source_path, options.type)
  text_content = text_like?(extension) ? read_text_content(options.source_path) : nil
  source_sha = digest_file(options.source_path)
  source_bytes = options.source_path.size
  slug = slug_for(options.source_path)
  targets = destination_targets(options, slug, options.source_path.extname)

  payload_staging = staged_path(targets.payload)
  artifact_staging = staged_path(targets.artifact)
  draft_staging = staged_path(targets.draft)
  staged = [payload_staging, artifact_staging, draft_staging]

  payload_staging.dirname.mkpath
  FileUtils.copy_file(options.source_path.to_s, payload_staging.to_s)
  unless digest_file(payload_staging) == source_sha && payload_staging.size == source_bytes
    raise IngestArtifactError, "copied payload failed checksum verification"
  end

  payload_relative = vault_relative(targets.payload, options.vault_root)
  artifact_relative = vault_relative(targets.artifact, options.vault_root)
  artifact_id = targets.artifact.basename(".md").to_s
  draft_id = targets.draft.basename(".md").to_s
  source_metadata = SourceMetadata.new(
    payload_relative: payload_relative,
    original_filename: options.source_path.basename.to_s,
    sha256: source_sha,
    bytes: source_bytes
  )
  title = text_content ? title_from(text_content, slug) : "#{options.type.capitalize} Artifact"
  facts = text_content ? source_backed_facts(text_content) : "- Imported #{options.type} artifact metadata only."

  artifact = artifact_frontmatter(options, artifact_id, source_metadata)
  draft = draft_frontmatter(options, draft_id, artifact_id, artifact_relative)
  write_staged(
    artifact_staging,
    markdown_note(artifact, artifact_body(options, source_metadata, text_content))
  )
  write_staged(
    draft_staging,
    markdown_note(draft, draft_body(options, title, facts, source_metadata))
  )

  finalize!(payload_staging, targets.payload, created)
  finalize!(artifact_staging, targets.artifact, created)
  finalize!(draft_staging, targets.draft, created)

  puts "copied_source: #{targets.payload}"
  puts "artifact: #{targets.artifact}"
  puts "draft_note: #{targets.draft}"
rescue StandardError
  cleanup(staged)
  cleanup(created)
  raise
end

begin
  ingest(parse_options(ARGV))
rescue IngestArtifactError, SystemCallError, Psych::Exception => error
  warn "ingest_artifact: #{error.message}"
  exit 1
end
