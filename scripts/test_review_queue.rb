#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"
require "psych"
require "tmpdir"

ROOT = Pathname(__dir__).parent.expand_path
SCRIPT = ROOT + "scripts/review_queue.rb"
REVIEW_TIME = "2026-06-28T21:00:00Z"
REVIEW_DATE = "2026-06-28"
MERGE_TARGET_ERROR = "merge target must be inside vault/02_notes or vault/03_canonical_model"

def run_review(vault, *args, editor: :unset)
  env = { "NOUS_REVIEW_TIME" => REVIEW_TIME }
  env["EDITOR"] = nil if editor == :unset
  env["EDITOR"] = editor if editor.is_a?(String)

  command = ["ruby", SCRIPT.to_s, args.first, "--vault-root", vault.to_s, *args.drop(1)]
  stdout, stderr, status = Open3.capture3(env, *command)
  [stdout, stderr, status]
end

def assert(condition, message)
  raise message unless condition
end

def assert_no_repo_vault_writes
  repo_vault = ROOT + "vault"
  return unless repo_vault.directory?

  markers = ["Focused writing helps decisions", "claim_2026-06-01_decisions", "edge_2026-06-03_decisions"]
  leaked = repo_vault.find.select(&:file?).select do |path|
    text = path.binread
    markers.any? { |marker| path.to_s.include?(marker) || text.include?(marker) }
  end
  assert(leaked.empty?, "review_queue fixtures leaked into repo vault: #{leaked.map(&:to_s).inspect}")
end

def yaml_frontmatter(data)
  Psych.dump(data).sub(/\A---\n/, "")
end

def write_note(path, frontmatter, body = "# Test\n\n## Review Notes\n")
  path.dirname.mkpath
  path.write("---\n#{yaml_frontmatter(frontmatter)}---\n\n#{body}")
end

def frontmatter(path)
  text = path.read
  match = text.match(/\A---\n(.*?)\n---\n/m)
  raise "missing frontmatter in #{path}" unless match

  Psych.safe_load(match[1], aliases: false)
end

def list_paths(stdout)
  stdout.lines.drop(1).map { |line| line.split("\t")[2] }
end

def fixture_vault(tmpdir, name)
  vault = tmpdir + name
  artifact = vault + "00_raw_artifacts/text/artifact_2026-06-01_reflection.md"
  write_note(
    artifact,
    {
      "id" => "artifact_2026-06-01_reflection",
      "type" => "artifact",
      "schema_version" => "0.1",
      "status" => "draft",
      "review_status" => "needs_review",
      "created" => "2026-06-01",
      "updated" => "2026-06-01",
      "source" => { "type" => "text", "path" => "/tmp/reflection.txt", "extraction_method" => "import" },
      "interpretation_level" => "none",
      "tags" => []
    },
    "# Artifact\n\n## Observed Content\n\nFocused writing helps decisions.\n"
  )

  note = vault + "01_agent_inbox/notes/note_2026-06-02_reflection.md"
  write_note(
    note,
    {
      "id" => "note_2026-06-02_reflection",
      "type" => "note",
      "schema_version" => "0.1",
      "status" => "draft",
      "review_status" => "agent_generated",
      "confidence" => 0.6,
      "created" => "2026-06-02",
      "updated" => "2026-06-02",
      "source" => { "type" => "text", "path" => "00_raw_artifacts/text/artifact_2026-06-01_reflection.md", "extraction_method" => "archivist_agent" },
      "interpretation_level" => "low",
      "evidence" => [{ "id" => "artifact_2026-06-01_reflection", "path" => "00_raw_artifacts/text/artifact_2026-06-01_reflection.md" }],
      "counterevidence" => [],
      "related" => [],
      "tags" => []
    },
    "# Reflection\n\n## Source-Backed Facts\n\n- Focused writing helps decisions.\n\n## Review Notes\n"
  )

  claim = vault + "01_agent_inbox/claims/claim_2026-06-01_decisions.md"
  write_note(
    claim,
    {
      "id" => "claim_2026-06-01_decisions",
      "type" => "claim",
      "schema_version" => "0.1",
      "status" => "draft",
      "review_status" => "needs_review",
      "confidence" => 0.9,
      "created" => "2026-06-01",
      "updated" => "2026-06-01",
      "source" => { "type" => "text", "path" => "00_raw_artifacts/text/artifact_2026-06-01_reflection.md", "extraction_method" => "archivist_agent" },
      "interpretation_level" => "low",
      "evidence" => [{ "id" => "artifact_2026-06-01_reflection", "path" => "00_raw_artifacts/text/artifact_2026-06-01_reflection.md" }],
      "counterevidence" => [],
      "tags" => []
    },
    "# Claim\n\nFocused writing helps the user make decisions.\n"
  )

  relationship = vault + "01_agent_inbox/relationships/edge_2026-06-03_decisions.md"
  write_note(
    relationship,
    {
      "id" => "edge_2026-06-03_decisions",
      "type" => "relationship",
      "schema_version" => "0.1",
      "status" => "draft",
      "review_status" => "agent_generated",
      "confidence" => 0.4,
      "created" => "2026-06-03",
      "updated" => "2026-06-03",
      "source" => { "type" => "text", "path" => "00_raw_artifacts/text/artifact_2026-06-01_reflection.md", "extraction_method" => "archivist_agent" },
      "relationship" => { "from" => "note_2026-06-02_reflection", "to" => "claim_2026-06-01_decisions", "type" => "supports" },
      "interpretation_level" => "low",
      "evidence" => [{ "id" => "artifact_2026-06-01_reflection", "path" => "00_raw_artifacts/text/artifact_2026-06-01_reflection.md" }],
      "counterevidence" => [],
      "tags" => []
    },
    "# Relationship\n\n## Relationship Statement\n\nThe note supports the claim.\n"
  )

  {
    vault: vault,
    artifact: artifact,
    note: note,
    claim: claim,
    relationship: relationship
  }
end

def assert_success(status, stderr)
  assert(status.success?, "expected command to pass: #{stderr}")
end

def assert_failure(status, stderr, expected)
  assert(!status.success?, "expected command to fail")
  assert(stderr.include?(expected), "expected error to include #{expected.inspect}, got #{stderr.inspect}")
end

def assert_merge_target_rejected(vault, source, target)
  _stdout, stderr, status = run_review(vault, "merge", "--into", target.to_s, source.to_s)
  assert_failure(status, stderr, MERGE_TARGET_ERROR)
end

Dir.mktmpdir("nous-review-queue-test-") do |dir|
  tmpdir = Pathname(dir)

  fixture = fixture_vault(tmpdir, "list-vault")
  stdout, stderr, status = run_review(fixture[:vault], "list")
  assert_success(status, stderr)
  assert(stdout.lines.first == "priority\tkind\tpath\treview_status\tcreated\tconfidence\tevidence\n", "list header is wrong")
  assert(list_paths(stdout) == [
    "01_agent_inbox/claims/claim_2026-06-01_decisions.md",
    "01_agent_inbox/relationships/edge_2026-06-03_decisions.md",
    "01_agent_inbox/notes/note_2026-06-02_reflection.md"
  ], "priority ordering is wrong")
  assert(stdout.include?("00_raw_artifacts/text/artifact_2026-06-01_reflection.md"), "list should include evidence path")

  stdout, stderr, status = run_review(fixture[:vault], "list", "--sort", "created")
  assert_success(status, stderr)
  assert(list_paths(stdout) == [
    "01_agent_inbox/claims/claim_2026-06-01_decisions.md",
    "01_agent_inbox/notes/note_2026-06-02_reflection.md",
    "01_agent_inbox/relationships/edge_2026-06-03_decisions.md"
  ], "created ordering is wrong")

  stdout, stderr, status = run_review(fixture[:vault], "list", "--sort", "confidence")
  assert_success(status, stderr)
  assert(list_paths(stdout) == [
    "01_agent_inbox/claims/claim_2026-06-01_decisions.md",
    "01_agent_inbox/notes/note_2026-06-02_reflection.md",
    "01_agent_inbox/relationships/edge_2026-06-03_decisions.md"
  ], "confidence ordering is wrong")

  before_show = fixture[:note].read
  stdout, stderr, status = run_review(fixture[:vault], "show", fixture[:note].to_s)
  assert_success(status, stderr)
  assert(stdout.include?("Path: 01_agent_inbox/notes/note_2026-06-02_reflection.md"), "show should print path")
  assert(stdout.include?("--- Frontmatter ---"), "show should print frontmatter")
  assert(stdout.include?("## Source-Backed Facts"), "show should print review-relevant body")
  assert(stdout.include?("- 00_raw_artifacts/text/artifact_2026-06-01_reflection.md"), "show should print evidence")
  assert(fixture[:note].read == before_show, "show must not mutate the item")

  fixture = fixture_vault(tmpdir, "note-approval-vault")
  _stdout, stderr, status = run_review(fixture[:vault], "approve", fixture[:note].to_s)
  assert_failure(status, stderr, "requires --as TYPE")
  _stdout, stderr, status = run_review(fixture[:vault], "approve", "--as", "essay", fixture[:note].to_s)
  assert_failure(status, stderr, "unsupported note type")
  stdout, stderr, status = run_review(fixture[:vault], "approve", "--as", "memory", "--note", "Looks right.", fixture[:note].to_s)
  assert_success(status, stderr)
  note_destination = fixture[:vault] + "02_notes/memories/note_2026-06-02_reflection.md"
  assert(stdout.include?("approved:"), "approve should print a transition")
  assert(!fixture[:note].exist?, "approved note should move out of inbox")
  assert(note_destination.file?, "approved note destination is missing")
  note_frontmatter = frontmatter(note_destination)
  assert(note_frontmatter["type"] == "memory", "approved note type should be mapped")
  assert(note_frontmatter["status"] == "active", "approved note status is wrong")
  assert(note_frontmatter["review_status"] == "reviewed", "approved note review status is wrong")
  assert(note_frontmatter["updated"] == REVIEW_DATE, "approved note updated date is wrong")
  assert(note_frontmatter["review"] == {
    "decision" => "approved",
    "decided_at" => REVIEW_TIME,
    "reviewer_note" => "Looks right."
  }, "approved note review metadata is wrong")

  fixture = fixture_vault(tmpdir, "claim-approval-vault")
  stdout, stderr, status = run_review(fixture[:vault], "approve", fixture[:claim].to_s)
  assert_success(status, stderr)
  claim_destination = fixture[:vault] + "03_canonical_model/claims/claim_2026-06-01_decisions.md"
  assert(stdout.include?("03_canonical_model/claims/claim_2026-06-01_decisions.md"), "claim approval output is wrong")
  assert(!fixture[:claim].exist?, "approved claim should move out of inbox")
  assert(claim_destination.file?, "approved claim destination is missing")
  assert(frontmatter(claim_destination)["review_status"] == "reviewed", "approved claim review status is wrong")

  fixture = fixture_vault(tmpdir, "relationship-approval-vault")
  stdout, stderr, status = run_review(fixture[:vault], "approve", fixture[:relationship].to_s)
  assert_success(status, stderr)
  relationship_destination = fixture[:vault] + "03_canonical_model/relationships/edge_2026-06-03_decisions.md"
  assert(stdout.include?("03_canonical_model/relationships/edge_2026-06-03_decisions.md"), "relationship approval output is wrong")
  assert(!fixture[:relationship].exist?, "approved relationship should move out of inbox")
  assert(relationship_destination.file?, "approved relationship destination is missing")
  assert(frontmatter(relationship_destination)["review_status"] == "reviewed", "approved relationship review status is wrong")

  fixture = fixture_vault(tmpdir, "reject-vault")
  stdout, stderr, status = run_review(fixture[:vault], "reject", "--note", "Not accurate.", fixture[:claim].to_s)
  assert_success(status, stderr)
  assert(stdout.include?("rejected:"), "reject output is wrong")
  rejected_frontmatter = frontmatter(fixture[:claim])
  assert(rejected_frontmatter["status"] == "archived", "rejected item should be archived")
  assert(rejected_frontmatter["review_status"] == "rejected", "rejected item review status is wrong")
  assert(rejected_frontmatter["review"]["decision"] == "rejected", "rejected decision metadata is wrong")
  stdout, stderr, status = run_review(fixture[:vault], "list")
  assert_success(status, stderr)
  assert(!stdout.include?("claim_2026-06-01_decisions.md"), "rejected item should leave pending queue")

  fixture = fixture_vault(tmpdir, "deprecate-vault")
  stdout, stderr, status = run_review(fixture[:vault], "deprecate", fixture[:relationship].to_s)
  assert_success(status, stderr)
  assert(stdout.include?("deprecated:"), "deprecate output is wrong")
  deprecated_frontmatter = frontmatter(fixture[:relationship])
  assert(deprecated_frontmatter["status"] == "archived", "deprecated item should be archived")
  assert(deprecated_frontmatter["review_status"] == "deprecated", "deprecated review status is wrong")

  fixture = fixture_vault(tmpdir, "merge-vault")
  target = fixture[:vault] + "02_notes/memories/memory_2026-06-04_target.md"
  write_note(
    target,
    {
      "id" => "memory_2026-06-04_target",
      "type" => "memory",
      "schema_version" => "0.1",
      "status" => "active",
      "review_status" => "reviewed",
      "confidence" => 0.8,
      "created" => "2026-06-04",
      "updated" => "2026-06-04",
      "source" => { "type" => "manual", "path" => "manual", "extraction_method" => "manual" },
      "interpretation_level" => "low",
      "evidence" => [{ "id" => "existing", "path" => "existing.md" }],
      "counterevidence" => [],
      "tags" => []
    }
  )
  _stdout, stderr, status = run_review(fixture[:vault], "merge", fixture[:note].to_s)
  assert_failure(status, stderr, "merge requires --into PATH")
  stdout, stderr, status = run_review(fixture[:vault], "merge", "--into", target.to_s, "--note", "Folded into memory.", fixture[:note].to_s)
  assert_success(status, stderr)
  assert(stdout.include?("merged:"), "merge output is wrong")
  merged_source = frontmatter(fixture[:note])
  assert(merged_source["status"] == "archived", "merged source should be archived")
  assert(merged_source["review_status"] == "reviewed", "merged source review status should no longer be pending")
  assert(merged_source["review"] == {
    "decision" => "merged",
    "decided_at" => REVIEW_TIME,
    "reviewer_note" => "Folded into memory.",
    "merged_into" => "02_notes/memories/memory_2026-06-04_target.md"
  }, "merged source metadata is wrong")
  target_evidence = frontmatter(target)["evidence"]
  assert(target_evidence.include?({ "id" => "existing", "path" => "existing.md" }), "merge should preserve target evidence")
  assert(target_evidence.include?({ "id" => "artifact_2026-06-01_reflection", "path" => "00_raw_artifacts/text/artifact_2026-06-01_reflection.md" }), "merge should append source evidence")
  assert(target_evidence.include?({ "id" => "note_2026-06-02_reflection", "path" => "01_agent_inbox/notes/note_2026-06-02_reflection.md" }), "merge should append source provenance")
  stdout, stderr, status = run_review(fixture[:vault], "list")
  assert_success(status, stderr)
  assert(!stdout.include?("note_2026-06-02_reflection.md"), "merged source should leave pending queue")

  fixture = fixture_vault(tmpdir, "merge-boundary-vault")
  raw_before = fixture[:artifact].read
  assert_merge_target_rejected(fixture[:vault], fixture[:note], fixture[:artifact])
  assert(fixture[:artifact].read == raw_before, "raw artifact merge rejection should not mutate target")
  assert_merge_target_rejected(fixture[:vault], fixture[:note], fixture[:claim])
  report_target = fixture[:vault] + "04_generated/reports/report_target.md"
  write_note(report_target, frontmatter(fixture[:note]))
  assert_merge_target_rejected(fixture[:vault], fixture[:note], report_target)
  external_target = tmpdir + "external_target.md"
  write_note(external_target, frontmatter(fixture[:note]))
  assert_merge_target_rejected(fixture[:vault], fixture[:note], external_target)

  fixture = fixture_vault(tmpdir, "duplicate-vault")
  duplicate_destination = fixture[:vault] + "03_canonical_model/claims/claim_2026-06-01_decisions.md"
  write_note(duplicate_destination, frontmatter(fixture[:claim]))
  _stdout, stderr, status = run_review(fixture[:vault], "approve", fixture[:claim].to_s)
  assert_failure(status, stderr, "destination already exists")
  assert(fixture[:claim].file?, "duplicate approval failure should leave source in place")

  fixture = fixture_vault(tmpdir, "report-vault")
  rejected = fixture[:vault] + "01_agent_inbox/notes/note_2026-06-05_rejected.md"
  write_note(
    rejected,
    {
      "id" => "note_2026-06-05_rejected",
      "type" => "note",
      "schema_version" => "0.1",
      "status" => "archived",
      "review_status" => "rejected",
      "created" => "2026-06-05",
      "updated" => "2026-06-05",
      "source" => { "type" => "manual", "path" => "manual", "extraction_method" => "manual" },
      "tags" => []
    }
  )
  stdout, stderr, status = run_review(fixture[:vault], "report")
  assert_success(status, stderr)
  report = fixture[:vault] + "04_generated/reports/review_queue.md"
  assert(stdout.include?("report:"), "report command should print output path")
  assert(report.file?, "report file was not created")
  report_text = report.read
  assert(report_text.include?("- Pending items: 3"), "report pending count is wrong")
  assert(report_text.include?("01_agent_inbox/claims/claim_2026-06-01_decisions.md"), "report should include pending claim")
  assert(!report_text.include?("note_2026-06-05_rejected.md"), "report should exclude rejected item")

  fixture = fixture_vault(tmpdir, "edit-vault")
  _stdout, stderr, status = run_review(fixture[:vault], "edit", fixture[:note].to_s)
  assert_failure(status, stderr, "EDITOR is not set")
  stdout, stderr, status = run_review(
    fixture[:vault],
    "edit",
    fixture[:note].to_s,
    editor: "ruby -e \"File.open(ARGV[0], 'a') { |file| file.puts 'edited-by-test' }\""
  )
  assert_success(status, stderr)
  assert(stdout.include?("edited:"), "edit success output is wrong")
  assert(fixture[:note].read.include?("edited-by-test"), "edit should invoke multi-word EDITOR command with item path")

  assert_no_repo_vault_writes
end

puts "review_queue tests ok"
