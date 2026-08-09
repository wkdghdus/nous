#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "psych"
require "tmpdir"

ROOT = Pathname(__dir__).parent.expand_path
SCRIPT = ROOT + "scripts/export_graph.rb"
GRAPH_TIME = "2026-06-29T12:34:56Z"
LONG_SUMMARY = "#{"x" * 260} tail"

def run_export(vault, output, env: {})
  command_env = { "NOUS_GRAPH_TIME" => GRAPH_TIME }.merge(env)
  command = ["ruby", SCRIPT.to_s, "--vault-root", vault.to_s, "--output", output.to_s]
  stdout, stderr, status = Open3.capture3(command_env, *command)
  [stdout, stderr, status]
end

def assert(condition, message)
  raise message unless condition
end

def assert_no_repo_vault_writes
  repo_vault = ROOT + "vault"
  return unless repo_vault.directory?

  markers = ["memory_2026-06-29_focus", "claim_2026-06-29_focus", "edge_2026-06-29_focus"]
  leaked = repo_vault.find.select(&:file?).select do |path|
    text = path.binread
    markers.any? { |marker| path.to_s.include?(marker) || text.include?(marker) }
  end
  assert(leaked.empty?, "export_graph fixtures leaked into repo vault: #{leaked.map(&:to_s).inspect}")
end

def assert_success(status, stderr)
  assert(status.success?, "expected command to pass: #{stderr}")
end

def assert_failure(status, stderr, expected)
  assert(!status.success?, "expected command to fail")
  assert(stderr.include?(expected), "expected error to include #{expected.inspect}, got #{stderr.inspect}")
end

def yaml_frontmatter(data)
  Psych.dump(data).sub(/\A---\n/, "")
end

def write_record(path, frontmatter, body)
  path.dirname.mkpath
  path.write("---\n#{yaml_frontmatter(frontmatter)}---\n\n#{body}")
end

def read_graph(path)
  JSON.parse(path.read)
end

def base_frontmatter(id, type, extra = {})
  {
    "id" => id,
    "type" => type,
    "schema_version" => "0.1",
    "status" => "active",
    "review_status" => "reviewed",
    "confidence" => 0.8,
    "created" => "2026-06-29",
    "updated" => "2026-06-29",
    "evidence" => [
      { "id" => "artifact_2026-06-01_reflection", "path" => "00_raw_artifacts/text/artifact_2026-06-01_reflection.md" },
      { "id" => "artifact_2026-06-01_reflection", "path" => "00_raw_artifacts/text/artifact_2026-06-01_reflection.md" },
      { "id" => "", "path" => "ignored.md" },
      { "id" => "ignored", "path" => "" },
      { "id" => "artifact_2026-06-02_journal", "path" => "00_raw_artifacts/writing/artifact_2026-06-02_journal.md" }
    ]
  }.merge(extra)
end

def relationship_frontmatter(id, from, to, type = "supports", extra = {})
  base_frontmatter(
    id,
    "relationship",
    {
      "relationship" => { "from" => from, "to" => to, "type" => type },
      "confidence" => 0.7
    }.merge(extra)
  )
end

def success_fixture(vault)
  write_record(
    vault + "02_notes/memories/memory_2026-06-29_focus.md",
    base_frontmatter("memory_2026-06-29_focus", "memory"),
    "# Focused Writing\n\nFocused writing helps decisions.\n\n## Review Notes\n"
  )
  write_record(
    vault + "02_notes/beliefs/belief_2026-06-29_long.md",
    base_frontmatter("belief_2026-06-29_long", "belief", "title" => "Long Body Belief"),
    "#{LONG_SUMMARY}\n"
  )
  write_record(
    vault + "02_notes/questions/question_2026-06-29_open.md",
    base_frontmatter("question_2026-06-29_open", "question"),
    "\n"
  )
  write_record(
    vault + "03_canonical_model/claims/claim_2026-06-29_focus.md",
    base_frontmatter("claim_2026-06-29_focus", "claim", "title" => "Focused writing supports decisions"),
    "Claim body supplies the deterministic summary.\n"
  )
  write_record(
    vault + "03_canonical_model/relationships/edge_2026-06-29_focus.md",
    relationship_frontmatter("edge_2026-06-29_focus", "memory_2026-06-29_focus", "claim_2026-06-29_focus"),
    "# Relationship\n\nThe memory supports the claim.\n"
  )

  write_record(
    vault + "01_agent_inbox/notes/note_2026-06-29_pending.md",
    base_frontmatter("note_2026-06-29_pending", "memory"),
    "# Pending\n\nThis must not export.\n"
  )
  write_record(
    vault + "02_notes/memories/memory_2026-06-29_rejected.md",
    base_frontmatter("memory_2026-06-29_rejected", "memory", "review_status" => "rejected"),
    "# Rejected\n\nThis must not export.\n"
  )
  write_record(
    vault + "03_canonical_model/claims/claim_2026-06-29_deprecated.md",
    base_frontmatter("claim_2026-06-29_deprecated", "claim", "review_status" => "deprecated"),
    "# Deprecated\n\nThis must not export.\n"
  )
  write_record(
    vault + "02_notes/memories/memory_2026-06-29_archived.md",
    base_frontmatter("memory_2026-06-29_archived", "memory", "status" => "archived"),
    "# Archived\n\nThis must not export.\n"
  )
end

def minimal_connected_fixture(vault)
  write_record(
    vault + "02_notes/memories/memory_a.md",
    base_frontmatter("memory_a", "memory"),
    "# Memory A\n"
  )
  write_record(
    vault + "03_canonical_model/claims/claim_a.md",
    base_frontmatter("claim_a", "claim"),
    "# Claim A\n"
  )
end

def assert_success_graph(graph)
  assert(graph.keys == ["schema_version", "generated_at", "nodes", "edges"], "top-level graph keys are wrong")
  assert(graph["schema_version"] == "0.1", "schema version is wrong")
  assert(graph["generated_at"] == GRAPH_TIME, "generated_at is wrong")

  nodes = graph.fetch("nodes")
  edges = graph.fetch("edges")
  node_ids = nodes.map { |node| node.fetch("id") }
  assert(node_ids == node_ids.sort, "nodes are not sorted by id")
  assert(node_ids == [
    "belief_2026-06-29_long",
    "claim_2026-06-29_focus",
    "memory_2026-06-29_focus",
    "question_2026-06-29_open"
  ], "unexpected exported node ids: #{node_ids.inspect}")
  assert(edges.map { |edge| edge.fetch("id") } == ["edge_2026-06-29_focus"], "unexpected exported edges")

  memory = nodes.find { |node| node.fetch("id") == "memory_2026-06-29_focus" }
  assert(memory["label"] == "Focused Writing", "H1 label extraction failed")
  assert(memory["summary"] == "Focused writing helps decisions.", "summary extraction failed")
  assert(memory["source_path"] == "02_notes/memories/memory_2026-06-29_focus.md", "source_path should be the reviewed record path")
  assert(memory["confidence"] == 0.8, "node confidence is wrong")
  assert(memory["review_status"] == "reviewed", "node review status is wrong")
  assert(memory["evidence"] == [
    { "id" => "artifact_2026-06-01_reflection", "path" => "00_raw_artifacts/text/artifact_2026-06-01_reflection.md" },
    { "id" => "artifact_2026-06-02_journal", "path" => "00_raw_artifacts/writing/artifact_2026-06-02_journal.md" }
  ], "evidence should be deduplicated in source order")

  claim = nodes.find { |node| node.fetch("id") == "claim_2026-06-29_focus" }
  assert(claim["label"] == "Focused writing supports decisions", "title label fallback failed")

  question = nodes.find { |node| node.fetch("id") == "question_2026-06-29_open" }
  assert(question["label"] == "question_2026-06-29_open", "id label fallback failed")
  assert(!question.key?("summary"), "blank bodies should omit summary")

  belief = nodes.find { |node| node.fetch("id") == "belief_2026-06-29_long" }
  assert(belief["summary"].length == 240, "summary should be bounded")

  edge = edges.first
  assert(edge["from"] == "memory_2026-06-29_focus", "edge from is wrong")
  assert(edge["to"] == "claim_2026-06-29_focus", "edge to is wrong")
  assert(edge["relationship"] == "supports", "edge relationship is wrong")
  assert(edge["confidence"] == 0.7, "edge confidence is wrong")
  assert(edge["evidence"] == memory["evidence"], "edge evidence should be deduplicated in source order")
end

Dir.mktmpdir("nous-export-graph-test-") do |dir|
  tmpdir = Pathname(dir)

  vault = tmpdir + "success-vault"
  output = tmpdir + "success.json"
  success_fixture(vault)
  stdout, stderr, status = run_export(vault, output)
  assert_success(status, stderr)
  assert(stdout.include?("graph:"), "export should print output path")
  assert_success_graph(read_graph(output))
  first_bytes = output.read
  _stdout, stderr, status = run_export(vault, output)
  assert_success(status, stderr)
  assert(output.read == first_bytes, "fixed-time export should be byte-identical across runs")

  vault = tmpdir + "duplicate-node-vault"
  output = tmpdir + "duplicate-node.json"
  output.write("previous\n")
  minimal_connected_fixture(vault)
  write_record(
    vault + "03_canonical_model/claims/claim_duplicate.md",
    base_frontmatter("memory_a", "claim"),
    "# Duplicate\n"
  )
  _stdout, stderr, status = run_export(vault, output)
  assert_failure(status, stderr, "duplicate node id")
  assert(output.read == "previous\n", "duplicate node failure should not overwrite existing output")

  vault = tmpdir + "duplicate-edge-vault"
  output = tmpdir + "duplicate-edge.json"
  minimal_connected_fixture(vault)
  write_record(
    vault + "03_canonical_model/relationships/edge_a.md",
    relationship_frontmatter("edge_a", "memory_a", "claim_a"),
    "# Edge A\n"
  )
  write_record(
    vault + "03_canonical_model/relationships/edge_b.md",
    relationship_frontmatter("edge_a", "memory_a", "claim_a"),
    "# Edge B\n"
  )
  _stdout, stderr, status = run_export(vault, output)
  assert_failure(status, stderr, "duplicate edge id")

  vault = tmpdir + "unsupported-node-vault"
  output = tmpdir + "unsupported-node.json"
  write_record(
    vault + "02_notes/memories/essay.md",
    base_frontmatter("essay_a", "essay"),
    "# Essay\n"
  )
  _stdout, stderr, status = run_export(vault, output)
  assert_failure(status, stderr, "unsupported node type")

  vault = tmpdir + "unsupported-edge-vault"
  output = tmpdir + "unsupported-edge.json"
  minimal_connected_fixture(vault)
  write_record(
    vault + "03_canonical_model/relationships/edge_a.md",
    relationship_frontmatter("edge_a", "memory_a", "claim_a", "depends_on"),
    "# Edge A\n"
  )
  _stdout, stderr, status = run_export(vault, output)
  assert_failure(status, stderr, "unsupported relationship type")

  vault = tmpdir + "misplaced-relationship-vault"
  output = tmpdir + "misplaced-relationship.json"
  minimal_connected_fixture(vault)
  write_record(
    vault + "02_notes/memories/edge_wrong_place.md",
    relationship_frontmatter("edge_wrong_place", "memory_a", "claim_a"),
    "# Misplaced Edge\n"
  )
  _stdout, stderr, status = run_export(vault, output)
  assert_failure(status, stderr, "relationship export records must be canonical relationships")

  vault = tmpdir + "missing-required-frontmatter-vault"
  output = tmpdir + "missing-required-frontmatter.json"
  write_record(
    vault + "02_notes/memories/memory_missing_id.md",
    base_frontmatter("memory_missing_id", "memory").reject { |key, _value| key == "id" },
    "# Missing ID\n"
  )
  _stdout, stderr, status = run_export(vault, output)
  assert_failure(status, stderr, "missing id")

  vault = tmpdir + "invalid-confidence-vault"
  output = tmpdir + "invalid-confidence.json"
  write_record(
    vault + "02_notes/memories/memory_bad_confidence.md",
    base_frontmatter("memory_bad_confidence", "memory", "confidence" => "high"),
    "# Bad Confidence\n"
  )
  _stdout, stderr, status = run_export(vault, output)
  assert_failure(status, stderr, "confidence must be numeric")

  vault = tmpdir + "dangling-edge-vault"
  output = tmpdir + "dangling-edge.json"
  minimal_connected_fixture(vault)
  write_record(
    vault + "03_canonical_model/relationships/edge_a.md",
    relationship_frontmatter("edge_a", "memory_a", "missing_claim"),
    "# Edge A\n"
  )
  _stdout, stderr, status = run_export(vault, output)
  assert_failure(status, stderr, "dangling edge")

  vault = tmpdir + "invalid-time-vault"
  output = tmpdir + "invalid-time.json"
  success_fixture(vault)
  _stdout, stderr, status = run_export(vault, output, env: { "NOUS_GRAPH_TIME" => "not-a-time" })
  assert_failure(status, stderr, "NOUS_GRAPH_TIME must be an ISO-8601 timestamp")

  assert_no_repo_vault_writes
end

puts "export graph tests ok"
