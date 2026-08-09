#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "optparse"
require "pathname"

ROOT = Pathname(__dir__).parent.expand_path
LIB = ROOT + "lib"
DEFAULT_VAULT_ROOT = ROOT + "vault"
SUPPORTED_EXTENSIONS = {
  "writing" => [".txt", ".md"],
  "image" => [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic"],
  "project" => [".txt", ".md", ".json", ".yaml", ".yml", ".jpg", ".jpeg", ".png", ".gif", ".webp"]
}.freeze

$LOAD_PATH.unshift(LIB.to_s)
require "nous"

class IngestArtifactError < StandardError; end

Options = Struct.new(:source_path, :vault_root, :today, :type, :context, :represented_date, keyword_init: true)

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

def ingest(options)
  result = Nous::ArtifactIngestion.ingest(
    source_path: options.source_path,
    vault_root: options.vault_root,
    type: options.type,
    date: options.today,
    context: options.context,
    represented_date: options.represented_date,
    source_error_path: options.source_path.to_s
  )

  puts "copied_source: #{options.vault_root + result.fetch(:copied_source_path)}"
  puts "artifact: #{options.vault_root + result.fetch(:artifact_path)}"
  puts "draft_note: #{options.vault_root + result.fetch(:draft_path)}"
end

begin
  ingest(parse_options(ARGV))
rescue IngestArtifactError, Nous::Error, SystemCallError => error
  warn "ingest_artifact: #{error.message}"
  exit 1
end
