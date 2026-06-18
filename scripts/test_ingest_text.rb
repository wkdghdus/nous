#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"
require "psych"
require "tmpdir"

ROOT = Pathname(__dir__).parent.expand_path
SCRIPT = ROOT + "scripts/ingest_text.rb"
TEST_DATE = "2026-06-14"

def run_ingest(source, vault_root)
  command = ["ruby", SCRIPT.to_s, "--date", TEST_DATE, "--vault-root", vault_root.to_s, source.to_s]
  stdout, stderr, status = Open3.capture3(*command)
  [stdout, stderr, status]
end

def assert(condition, message)
  raise message unless condition
end

def frontmatter(path)
  text = path.read
  match = text.match(/\A---\n(.*?)\n---\n/m)
  raise "missing frontmatter in #{path}" unless match

  Psych.safe_load(match[1], aliases: false)
end

def markdown_section(path, heading)
  text = path.read
  match = text.match(/^## #{Regexp.escape(heading)}\n\n(.*?)(?=^## |\z)/m)
  raise "missing section #{heading} in #{path}" unless match

  match[1].strip
end

def assert_successful_import(tmpdir, extension, vault_name)
  source = tmpdir + "source#{extension}"
  source.write("# Evening Reflection\n\nI noticed that focused writing helps me make decisions.\nI want tools that preserve context.")

  vault = tmpdir + vault_name
  stdout, stderr, status = run_ingest(source, vault)
  assert(status.success?, "expected import to pass: #{stderr}")

  artifact_path = Pathname(stdout.lines.find { |line| line.start_with?("artifact: ") }.split(": ", 2).last.strip)
  note_path = Pathname(stdout.lines.find { |line| line.start_with?("draft_note: ") }.split(": ", 2).last.strip)

  assert(artifact_path.file?, "artifact note was not created")
  assert(note_path.file?, "draft note was not created")
  assert(artifact_path.dirname.to_s.end_with?("vault/00_raw_artifacts/text"), "artifact path is wrong")
  assert(note_path.dirname.to_s.end_with?("vault/01_agent_inbox/notes"), "draft path is wrong")

  artifact = frontmatter(artifact_path)
  note = frontmatter(note_path)

  assert(artifact["id"] == "artifact_#{TEST_DATE}_source", "artifact id is wrong")
  assert(artifact["type"] == "artifact", "artifact type is wrong")
  assert(artifact["created"] == TEST_DATE, "artifact created date is wrong")
  assert(artifact["updated"] == TEST_DATE, "artifact updated date is wrong")
  assert(artifact["review_status"] == "needs_review", "artifact review status is wrong")
  assert(artifact["interpretation_level"] == "none", "artifact interpretation level is wrong")
  assert(artifact["source"]["type"] == "text", "artifact source type is wrong")
  assert(Pathname(artifact["source"]["path"]).realpath == source.realpath, "artifact source path is wrong")
  assert(artifact["source"]["extraction_method"] == "import", "artifact extraction method is wrong")
  assert(artifact_path.read.include?("I noticed that focused writing helps me make decisions."), "artifact content was not preserved")

  assert(note["id"] == "note_#{TEST_DATE}_source", "draft note id is wrong")
  assert(note["type"] == "note", "draft note type is wrong")
  assert(note["created"] == TEST_DATE, "draft note created date is wrong")
  assert(note["updated"] == TEST_DATE, "draft note updated date is wrong")
  assert(note["review_status"] == "agent_generated", "draft note review status is wrong")
  assert(note["interpretation_level"] == "low", "draft note interpretation level is wrong")
  assert(note["source"] == {
    "type" => "text",
    "path" => "00_raw_artifacts/text/#{artifact_path.basename}",
    "extraction_method" => "archivist_agent"
  }, "draft note source is wrong")
  assert(note["evidence"] == [{ "id" => artifact["id"], "path" => "00_raw_artifacts/text/#{artifact_path.basename}" }], "draft evidence is wrong")
  assert(markdown_section(note_path, "Source-Backed Facts") == [
    "- # Evening Reflection",
    "- I noticed that focused writing helps me make decisions.",
    "- I want tools that preserve context."
  ].join("\n"), "draft facts should be extractive")
  assert(markdown_section(note_path, "Tentative Hypotheses").empty?, "draft note should not add hypotheses")
end

Dir.mktmpdir("nous-ingest-test-") do |dir|
  tmpdir = Pathname(dir)

  assert_successful_import(tmpdir, ".txt", "txt-vault")
  assert_successful_import(tmpdir, ".md", "md-vault")

  duplicate_source = tmpdir + "duplicate.txt"
  duplicate_source.write("Repeated local text import.")
  vault = tmpdir + "duplicate-vault"
  first_stdout, first_stderr, first_status = run_ingest(duplicate_source, vault)
  second_stdout, second_stderr, second_status = run_ingest(duplicate_source, vault)
  assert(first_status.success?, "first duplicate import failed: #{first_stderr}")
  assert(second_status.success?, "second duplicate import failed: #{second_stderr}")
  first_artifact = first_stdout.lines.find { |line| line.start_with?("artifact: ") }
  second_artifact = second_stdout.lines.find { |line| line.start_with?("artifact: ") }
  first_note = first_stdout.lines.find { |line| line.start_with?("draft_note: ") }
  second_note = second_stdout.lines.find { |line| line.start_with?("draft_note: ") }
  assert(first_artifact.include?("artifact_#{TEST_DATE}_duplicate.md"), "first duplicate path is wrong")
  assert(second_artifact.include?("artifact_#{TEST_DATE}_duplicate-2.md"), "second duplicate path is wrong")
  assert(first_note.include?("note_#{TEST_DATE}_duplicate.md"), "first duplicate draft path is wrong")
  assert(second_note.include?("note_#{TEST_DATE}_duplicate-2.md"), "second duplicate draft path is wrong")

  empty_source = tmpdir + "empty.txt"
  empty_source.write("  \n")
  _stdout, stderr, status = run_ingest(empty_source, tmpdir + "empty-vault")
  assert(!status.success?, "empty source should fail")
  assert(stderr.include?("source file is empty"), "empty source error is not actionable")

  unsupported_source = tmpdir + "capture.pdf"
  unsupported_source.write("not text")
  _stdout, stderr, status = run_ingest(unsupported_source, tmpdir + "unsupported-vault")
  assert(!status.success?, "unsupported extension should fail")
  assert(stderr.include?("unsupported source extension"), "unsupported extension error is not actionable")

  invalid_source = tmpdir + "invalid.txt"
  invalid_source.binwrite("\xFF")
  _stdout, stderr, status = run_ingest(invalid_source, tmpdir + "invalid-vault")
  assert(!status.success?, "invalid UTF-8 source should fail")
  assert(stderr.include?("source file must be valid UTF-8"), "invalid UTF-8 error is not actionable")

  _stdout, stderr, status = run_ingest(tmpdir + "missing.txt", tmpdir + "missing-vault")
  assert(!status.success?, "missing source should fail")
  assert(stderr.include?("source path does not exist"), "missing source error is not actionable")

  directory_source = tmpdir + "directory.md"
  directory_source.mkdir
  _stdout, stderr, status = run_ingest(directory_source, tmpdir + "directory-vault")
  assert(!status.success?, "directory source should fail")
  assert(stderr.include?("source path is a directory"), "directory source error is not actionable")
end

puts "ingest_text tests ok"
