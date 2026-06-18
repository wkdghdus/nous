#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "optparse"
require "pathname"
require "psych"

ROOT = Pathname(__dir__).parent.expand_path
DEFAULT_VAULT_ROOT = ROOT + "vault"
SUPPORTED_EXTENSIONS = [".txt", ".md"].freeze

class IngestError < StandardError; end

Options = Struct.new(:source_path, :vault_root, :today, keyword_init: true)

def parse_options(argv)
  options = Options.new(vault_root: DEFAULT_VAULT_ROOT, today: ENV["NOUS_INGEST_DATE"])

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/ingest_text.rb [options] SOURCE_PATH"
    opts.on("--vault-root PATH", "Vault root to write into. Defaults to ./vault.") do |path|
      options.vault_root = Pathname(path).expand_path
    end
    opts.on("--date YYYY-MM-DD", "Import date. Defaults to today.") do |date|
      options.today = date
    end
    opts.on("-h", "--help", "Show this help.") do
      puts opts
      exit 0
    end
  end

  parser.parse!(argv)
  raise IngestError, "expected exactly one source path" unless argv.length == 1

  options.source_path = Pathname(argv.first).expand_path
  options.today = parse_date(options.today)
  options
rescue OptionParser::ParseError => error
  raise IngestError, error.message
end

def parse_date(value)
  return Date.today if value.nil? || value.empty?

  Date.iso8601(value)
rescue Date::Error
  raise IngestError, "date must use YYYY-MM-DD"
end

def validate_source(path)
  raise IngestError, "source path does not exist: #{path}" unless path.exist?
  raise IngestError, "source path is a directory: #{path}" if path.directory?

  extension = path.extname.downcase
  unless SUPPORTED_EXTENSIONS.include?(extension)
    raise IngestError, "unsupported source extension: #{extension.empty? ? "(none)" : extension}"
  end

  content = path.binread
  content.force_encoding("UTF-8")
  raise IngestError, "source file must be valid UTF-8: #{path}" unless content.valid_encoding?
  raise IngestError, "source file is empty: #{path}" if content.strip.empty?

  content
rescue Errno::ENOENT
  raise IngestError, "source path does not exist: #{path}"
rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
  raise IngestError, "source file must be valid UTF-8: #{path}"
end

def slug_for(path)
  base = path.basename(path.extname).to_s.downcase
  slug = base.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-+\z/, "")
  slug.empty? ? "untitled" : slug
end

def relative_or_absolute(path)
  relative = path.relative_path_from(ROOT)
  relative.to_s.start_with?("..") ? path.to_s : relative.to_s
rescue ArgumentError
  path.to_s
end

def next_available_path(directory, basename)
  path = directory + "#{basename}.md"
  return path unless path.exist?

  index = 2
  loop do
    candidate = directory + "#{basename}-#{index}.md"
    return candidate unless candidate.exist?

    index += 1
  end
end

def yaml_frontmatter(data)
  Psych.dump(data).sub(/\A---\n/, "")
end

def write_note(path, frontmatter, body)
  path.dirname.mkpath
  path.write("---\n#{yaml_frontmatter(frontmatter)}---\n\n#{body}")
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

def artifact_body(source_path, content, import_date)
  source = relative_or_absolute(source_path)

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

def ingest(options)
  content = validate_source(options.source_path)
  slug = slug_for(options.source_path)
  date = options.today.to_s
  source_path = relative_or_absolute(options.source_path)

  artifact_directory = options.vault_root + "00_raw_artifacts/text"
  notes_directory = options.vault_root + "01_agent_inbox/notes"

  artifact_base = "artifact_#{date}_#{slug}"
  artifact_path = next_available_path(artifact_directory, artifact_base)
  artifact_id = artifact_path.basename(".md").to_s

  draft_base = "note_#{date}_#{slug}"
  draft_path = next_available_path(notes_directory, draft_base)
  draft_id = draft_path.basename(".md").to_s

  artifact_frontmatter = {
    "id" => artifact_id,
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

  draft_frontmatter = {
    "id" => draft_id,
    "type" => "note",
    "schema_version" => "0.1",
    "status" => "draft",
    "review_status" => "agent_generated",
    "confidence" => 0.6,
    "created" => date,
    "updated" => date,
    "source" => {
      "type" => "text",
      "path" => artifact_path.relative_path_from(options.vault_root).to_s,
      "extraction_method" => "archivist_agent"
    },
    "interpretation_level" => "low",
    "evidence" => [
      {
        "id" => artifact_id,
        "path" => artifact_path.relative_path_from(options.vault_root).to_s
      }
    ],
    "counterevidence" => [],
    "related" => [],
    "tags" => []
  }

  write_note(artifact_path, artifact_frontmatter, artifact_body(options.source_path, content, date))
  write_note(draft_path, draft_frontmatter, draft_body(title_from(content, slug), source_backed_facts(content)))

  puts "artifact: #{artifact_path}"
  puts "draft_note: #{draft_path}"
end

begin
  ingest(parse_options(ARGV))
rescue IngestError => error
  warn "ingest_text: #{error.message}"
  exit 1
end
