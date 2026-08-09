#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "optparse"
require "pathname"

ROOT = Pathname(__dir__).parent.expand_path
LIB = ROOT + "lib"
DEFAULT_VAULT_ROOT = ROOT + "vault"

$LOAD_PATH.unshift(LIB.to_s)
require "nous"

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

def ingest(options)
  result = Nous::TextIngestion.ingest(
    source_path: options.source_path,
    vault_root: options.vault_root,
    date: options.today,
    source_display_base: ROOT,
    source_error_path: options.source_path.to_s
  )

  puts "artifact: #{options.vault_root + result.fetch(:artifact_path)}"
  puts "draft_note: #{options.vault_root + result.fetch(:draft_path)}"
end

begin
  ingest(parse_options(ARGV))
rescue IngestError, Nous::Error => error
  warn "ingest_text: #{error.message}"
  exit 1
end
