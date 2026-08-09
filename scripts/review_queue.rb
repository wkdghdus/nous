#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "pathname"
require "shellwords"
require "time"

$LOAD_PATH.unshift((Pathname(__dir__).parent + "lib").to_s)
require "nous"

ROOT = Pathname(__dir__).parent.expand_path
DEFAULT_VAULT_ROOT = ROOT + "vault"

class ReviewError < StandardError; end

Options = Struct.new(:vault_root, :sort, :note_type, :reviewer_note, :merge_target, :output_path, keyword_init: true)

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

def list_items(options)
  text = Nous::VaultLock.new(vault_root: options.vault_root).with_shared do
    Nous::Review.render_list(Nous::Review.list(vault_root: options.vault_root, sort: options.sort))
  end
  print text
end

def show_item(path, options)
  text = Nous::VaultLock.new(vault_root: options.vault_root).with_shared do
    Nous::Review.render_show(Nous::Review.show(path: path, vault_root: options.vault_root))
  end
  print text
end

def review_timestamp
  value = ENV["NOUS_REVIEW_TIME"]
  return Time.now.utc.iso8601 if value.nil? || value.empty?

  Time.iso8601(value).utc.iso8601
rescue ArgumentError
  raise ReviewError, "NOUS_REVIEW_TIME must be an ISO-8601 timestamp"
end

def approve_item(path, options)
  result = Nous::ReviewMutation.approve(
    path: path,
    vault_root: options.vault_root,
    timestamp: review_timestamp,
    note_type: options.note_type,
    reviewer_note: options.reviewer_note
  )
  puts "approved: #{result.fetch(:source_path)} -> #{result.fetch(:destination_path)}"
end

def reject_item(path, options, decision)
  result = Nous::ReviewMutation.reject(
    path: path,
    vault_root: options.vault_root,
    timestamp: review_timestamp,
    reviewer_note: options.reviewer_note,
    decision: decision
  )
  puts "#{decision}: #{result.fetch(:source_path)}"
end

def merge_item(path, options)
  raise ReviewError, "merge requires --into PATH" if options.merge_target.nil? || options.merge_target.empty?

  result = Nous::ReviewMutation.merge(
    path: path,
    vault_root: options.vault_root,
    target_path: resolve_path(options.merge_target, options.vault_root),
    timestamp: review_timestamp,
    reviewer_note: options.reviewer_note
  )
  puts "merged: #{result.fetch(:source_path)} -> #{result.fetch(:target_path)}"
end

def edit_item(path, options)
  item = Nous::ReviewMutation.resolve_for_edit(path: path, vault_root: options.vault_root)
  editor = ENV["EDITOR"]
  raise ReviewError, "EDITOR is not set" if editor.nil? || editor.empty?

  editor_command = Shellwords.split(editor)
  raise ReviewError, "EDITOR is not set" if editor_command.empty?

  success = system(*editor_command, item.fetch(:path).to_s)
  raise ReviewError, "editor exited unsuccessfully" unless success

  puts "edited: #{item.fetch(:relative_path)}"
rescue ArgumentError
  raise ReviewError, "EDITOR is not a valid shell-style command"
end

def report_path(options)
  return resolve_path(options.output_path, options.vault_root) unless options.output_path.nil? || options.output_path.empty?

  options.vault_root + "04_generated/reports/review_queue.md"
end

def generate_report(options)
  path = Nous::VaultLock.new(vault_root: options.vault_root).with_exclusive do
    timestamp = review_timestamp
    path = report_path(options)
    Nous::AtomicWriter.replace_adapter_path(
      path: path,
      bytes: Nous::Review.render_report(Nous::Review.report(vault_root: options.vault_root, generated_at: timestamp))
    )
    path
  end
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
