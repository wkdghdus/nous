#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "optparse"
require "pathname"
require "psych"
require "shellwords"
require "time"

$LOAD_PATH.unshift((Pathname(__dir__).parent + "lib").to_s)
require "nous"

ROOT = Pathname(__dir__).parent.expand_path
DEFAULT_VAULT_ROOT = ROOT + "vault"

INBOX_DIRS = {
  "note" => "01_agent_inbox/notes",
  "claim" => "01_agent_inbox/claims",
  "relationship" => "01_agent_inbox/relationships"
}.freeze

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

class ReviewError < StandardError; end

Options = Struct.new(:vault_root, :sort, :note_type, :reviewer_note, :merge_target, :output_path, keyword_init: true)

Item = Struct.new(:path, :relative_path, :kind, :frontmatter, :body, keyword_init: true)

def parse_options(command, argv)
  options = Options.new(vault_root: DEFAULT_VAULT_ROOT, sort: "priority")

  parser = OptionParser.new do |opts|
    opts.banner = usage_for(command)
    opts.on("--vault-root PATH", "Vault root. Defaults to ./vault.") do |path|
      options.vault_root = Pathname(path).expand_path
    end
    opts.on("--note TEXT", "Reviewer note for decision metadata.") do |note|
      options.reviewer_note = note
    end
    opts.on("-h", "--help", "Show this help.") do
      puts opts
      exit 0
    end

    case command
    when "list"
      opts.on("--sort FIELD", "Sort by priority, created, or confidence.") do |field|
        options.sort = field
      end
    when "approve"
      opts.on("--as TYPE", "Reviewed note type for inbox notes.") do |type|
        options.note_type = type
      end
    when "merge"
      opts.on("--into PATH", "Reviewed/canonical file to merge into.") do |path|
        options.merge_target = path
      end
    when "report"
      opts.on("--output PATH", "Report path. Defaults to vault/04_generated/reports/review_queue.md.") do |path|
        options.output_path = path
      end
    end
  end

  parser.parse!(argv)
  options.vault_root = options.vault_root.expand_path
  options
rescue OptionParser::ParseError => error
  raise ReviewError, error.message
end

def usage_for(command)
  case command
  when "list"
    "Usage: ruby scripts/review_queue.rb list [--sort priority|created|confidence] [--vault-root PATH]"
  when "show"
    "Usage: ruby scripts/review_queue.rb show PATH [--vault-root PATH]"
  when "approve"
    "Usage: ruby scripts/review_queue.rb approve PATH [--as TYPE] [--note TEXT] [--vault-root PATH]"
  when "reject"
    "Usage: ruby scripts/review_queue.rb reject PATH [--note TEXT] [--vault-root PATH]"
  when "deprecate", "deprecated"
    "Usage: ruby scripts/review_queue.rb deprecate PATH [--note TEXT] [--vault-root PATH]"
  when "merge"
    "Usage: ruby scripts/review_queue.rb merge PATH --into TARGET [--note TEXT] [--vault-root PATH]"
  when "edit"
    "Usage: ruby scripts/review_queue.rb edit PATH [--vault-root PATH]"
  when "report"
    "Usage: ruby scripts/review_queue.rb report [--output PATH] [--vault-root PATH]"
  else
    "Usage: ruby scripts/review_queue.rb COMMAND [options]"
  end
end

def parse_frontmatter(path)
  text = path.read
  match = text.match(/\A---\n(.*?)\n---\n?/m)
  raise ReviewError, "missing YAML frontmatter: #{path}" unless match

  frontmatter = Psych.safe_load(match[1], aliases: false) || {}
  raise ReviewError, "frontmatter must be a mapping: #{path}" unless frontmatter.is_a?(Hash)

  [frontmatter, text[match[0].length..] || ""]
rescue Psych::Exception => error
  raise ReviewError, "invalid YAML frontmatter in #{path}: #{error.message}"
end

def yaml_frontmatter(data)
  Psych.dump(data).sub(/\A---\n/, "")
end

def write_markdown(path, frontmatter, body)
  path.dirname.mkpath
  path.write("---\n#{yaml_frontmatter(frontmatter)}---\n#{body.start_with?("\n") ? body : "\n#{body}"}")
end

def relative_or_absolute(path, base)
  relative = path.expand_path.relative_path_from(base.expand_path)
  relative.to_s.start_with?("..") ? path.to_s : relative.to_s
rescue ArgumentError
  path.to_s
end

def resolve_path(value, vault_root)
  path = Pathname(value)
  return path.expand_path if path.absolute?

  cwd_path = path.expand_path
  return cwd_path if cwd_path.exist?

  (vault_root + value).expand_path
end

def vault_relative_realpath(path, vault_root)
  path.realpath.relative_path_from(vault_root.realpath).to_s
rescue ArgumentError
  nil
end

def validate_merge_target!(target, vault_root)
  raise ReviewError, "merge target does not exist: #{target}" unless target.file?
  unless target.extname == ".md" && target.basename.to_s != "AGENT.md"
    raise ReviewError, "merge target must be a Markdown reviewed or canonical record"
  end

  relative = vault_relative_realpath(target, vault_root)
  unless relative && MERGE_TARGET_PREFIXES.any? { |prefix| relative.start_with?(prefix) }
    raise ReviewError, MERGE_TARGET_ERROR
  end
end

def kind_for_path(path, vault_root)
  relative = relative_or_absolute(path, vault_root)
  INBOX_DIRS.each do |kind, directory|
    return kind if relative.start_with?("#{directory}/")
  end

  nil
end

def load_item(path, vault_root)
  raise ReviewError, "path does not exist: #{path}" unless path.file?

  kind = kind_for_path(path, vault_root)
  raise ReviewError, "path is not in a review inbox: #{relative_or_absolute(path, vault_root)}" if kind.nil?

  frontmatter, body = parse_frontmatter(path)
  Item.new(
    path: path,
    relative_path: relative_or_absolute(path, vault_root),
    kind: kind,
    frontmatter: frontmatter,
    body: body
  )
end

def list_items(options)
  print Nous::Review.render_list(Nous::Review.list(vault_root: options.vault_root, sort: options.sort))
end

def show_item(path, options)
  print Nous::Review.render_show(Nous::Review.show(path: path, vault_root: options.vault_root))
end

def review_timestamp
  value = ENV["NOUS_REVIEW_TIME"]
  return Time.now.utc.iso8601 if value.nil? || value.empty?

  Time.iso8601(value).utc.iso8601
rescue ArgumentError
  raise ReviewError, "NOUS_REVIEW_TIME must be an ISO-8601 timestamp"
end

def review_date(timestamp)
  Time.iso8601(timestamp).utc.strftime("%Y-%m-%d")
end

def review_metadata(decision, timestamp, note: nil, merged_into: nil)
  metadata = {
    "decision" => decision,
    "decided_at" => timestamp
  }
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

def destination_for_approval(item, options)
  case item.kind
  when "note"
    note_type = options.note_type
    raise ReviewError, "approving an inbox note requires --as TYPE" if note_type.nil? || note_type.empty?
    unless NOTE_TYPE_DIRS.key?(note_type)
      raise ReviewError, "unsupported note type: #{note_type}; expected one of #{NOTE_TYPE_DIRS.keys.join(", ")}"
    end

    item.frontmatter["type"] = note_type
    options.vault_root + "02_notes/#{NOTE_TYPE_DIRS.fetch(note_type)}/#{item.path.basename}"
  when "claim"
    options.vault_root + "03_canonical_model/claims/#{item.path.basename}"
  when "relationship"
    options.vault_root + "03_canonical_model/relationships/#{item.path.basename}"
  else
    raise ReviewError, "unsupported item kind: #{item.kind}"
  end
end

def approve_item(path, options)
  item = load_item(path, options.vault_root)
  timestamp = review_timestamp
  destination = destination_for_approval(item, options)
  if destination.exist?
    raise ReviewError, "destination already exists: #{relative_or_absolute(destination, options.vault_root)}"
  end

  apply_decision(
    item.frontmatter,
    "approved",
    timestamp,
    status: "active",
    review_status: "reviewed",
    note: options.reviewer_note
  )
  write_markdown(item.path, item.frontmatter, item.body)
  destination.dirname.mkpath
  FileUtils.mv(item.path.to_s, destination.to_s)
  puts "approved: #{item.relative_path} -> #{relative_or_absolute(destination, options.vault_root)}"
end

def reject_item(path, options, decision)
  item = load_item(path, options.vault_root)
  timestamp = review_timestamp
  review_status = decision == "deprecated" ? "deprecated" : "rejected"
  apply_decision(
    item.frontmatter,
    decision,
    timestamp,
    status: "archived",
    review_status: review_status,
    note: options.reviewer_note
  )
  write_markdown(item.path, item.frontmatter, item.body)
  puts "#{decision}: #{item.relative_path}"
end

def evidence_entries(frontmatter)
  entries = []
  evidence = frontmatter["evidence"]
  if evidence.is_a?(Array)
    entries.concat(evidence.select { |entry| entry.is_a?(Hash) && entry["path"] })
  end

  entries
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

def merge_item(path, options)
  raise ReviewError, "merge requires --into PATH" if options.merge_target.nil? || options.merge_target.empty?

  item = load_item(path, options.vault_root)
  target = resolve_path(options.merge_target, options.vault_root)
  validate_merge_target!(target, options.vault_root)

  target_frontmatter, target_body = parse_frontmatter(target)
  timestamp = review_timestamp
  source_reference = {
    "id" => item.frontmatter["id"].to_s,
    "path" => item.relative_path
  }
  target_frontmatter["evidence"] = uniq_evidence(
    evidence_entries(target_frontmatter) + evidence_entries(item.frontmatter) + [source_reference]
  )
  target_frontmatter["updated"] = review_date(timestamp)
  write_markdown(target, target_frontmatter, target_body)

  apply_decision(
    item.frontmatter,
    "merged",
    timestamp,
    status: "archived",
    review_status: "reviewed",
    note: options.reviewer_note,
    merged_into: relative_or_absolute(target, options.vault_root)
  )
  write_markdown(item.path, item.frontmatter, item.body)
  puts "merged: #{item.relative_path} -> #{relative_or_absolute(target, options.vault_root)}"
end

def edit_item(path, options)
  item = load_item(path, options.vault_root)
  editor = ENV["EDITOR"]
  raise ReviewError, "EDITOR is not set" if editor.nil? || editor.empty?

  editor_command = Shellwords.split(editor)
  raise ReviewError, "EDITOR is not set" if editor_command.empty?

  success = system(*editor_command, item.path.to_s)
  raise ReviewError, "editor exited unsuccessfully" unless success

  puts "edited: #{item.relative_path}"
rescue ArgumentError
  raise ReviewError, "EDITOR is not a valid shell-style command"
end

def report_path(options)
  return resolve_path(options.output_path, options.vault_root) unless options.output_path.nil? || options.output_path.empty?

  options.vault_root + "04_generated/reports/review_queue.md"
end

def generate_report(options)
  timestamp = review_timestamp
  path = report_path(options)
  path.dirname.mkpath
  path.write(Nous::Review.render_report(Nous::Review.report(vault_root: options.vault_root, generated_at: timestamp)))
  puts "report: #{relative_or_absolute(path, options.vault_root)}"
end

def require_arity(command, argv, count)
  raise ReviewError, "#{command} expects #{count} path argument#{count == 1 ? "" : "s"}" unless argv.length == count
end

def run(argv)
  command = argv.shift
  raise ReviewError, usage_for(nil) if command.nil?

  options = parse_options(command, argv)
  case command
  when "list"
    require_arity(command, argv, 0)
    list_items(options)
  when "show"
    require_arity(command, argv, 1)
    show_item(resolve_path(argv.first, options.vault_root), options)
  when "approve"
    require_arity(command, argv, 1)
    approve_item(resolve_path(argv.first, options.vault_root), options)
  when "reject"
    require_arity(command, argv, 1)
    reject_item(resolve_path(argv.first, options.vault_root), options, "rejected")
  when "deprecate", "deprecated"
    require_arity(command, argv, 1)
    reject_item(resolve_path(argv.first, options.vault_root), options, "deprecated")
  when "merge"
    require_arity(command, argv, 1)
    merge_item(resolve_path(argv.first, options.vault_root), options)
  when "edit"
    require_arity(command, argv, 1)
    edit_item(resolve_path(argv.first, options.vault_root), options)
  when "report"
    require_arity(command, argv, 0)
    generate_report(options)
  else
    raise ReviewError, "unknown command: #{command}"
  end
end

begin
  run(ARGV)
rescue ReviewError, Nous::Error => error
  warn "review_queue: #{error.message}"
  exit 1
end
