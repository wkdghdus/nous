#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ruby <<'RUBY'
require "json"
require "psych"
require "pathname"

ROOT = Pathname.pwd
tracked_and_new = `git ls-files --cached --others --exclude-standard`.lines.map(&:chomp).reject(&:empty?)
FILES = tracked_and_new.map { |entry| Pathname(entry) }.select(&:file?).sort

def each_repo_file
  FILES.each { |path| yield path }
end

errors = []

each_repo_file do |path|
  text = path.binread
  next if text.empty?

  unless text.end_with?("\n")
    errors << "#{path}: missing final newline"
  end

  next unless [".md", ".json", ".yaml", ".yml", ".sh", ""].include?(path.extname)

  text.each_line.with_index(1) do |line, number|
    errors << "#{path}:#{number}: trailing whitespace" if line.match?(/[ \t]+$/)
  end
end

FILES.select { |path| path.extname == ".json" }.each do |path|
  JSON.parse(path.read)
rescue JSON::ParserError => error
  errors << "#{path}: invalid JSON: #{error.message}"
end

FILES.select { |path| [".yaml", ".yml"].include?(path.extname) }.each do |path|
  Psych.safe_load(path.read, permitted_classes: [Date], aliases: false)
rescue Psych::Exception => error
  errors << "#{path}: invalid YAML: #{error.message}"
end

dirs = FILES.map(&:dirname).uniq.sort
dirs.each do |path|
  next if path.to_s == "."
  next unless path.directory?

  errors << "#{path}: missing AGENT.md signpost" unless (path + "AGENT.md").file?
end

if File.exist?("package.json")
  errors << "package.json exists; this repo has not adopted an app runtime yet"
end

if errors.any?
  warn errors.join("\n")
  exit 1
end

puts "lint ok"
RUBY
