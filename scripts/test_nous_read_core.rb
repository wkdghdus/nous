#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "psych"
require "tmpdir"

ROOT = Pathname(__dir__).parent.expand_path
LIB = ROOT + "lib"
GRAPH_TIME = "2026-08-09T01:00:00Z"
REPORT_TIME = "2026-08-09T02:00:00Z"
REVIEW_TIME = "2026-08-09T03:00:00Z"

$LOAD_PATH.unshift(LIB.to_s)
require "nous"

def assert(condition, message)
  raise message unless condition
end

def yaml_frontmatter(data)
  Psych.dump(data).sub(/\A---\n/, "")
end

def write_record(path, frontmatter, body)
  path.dirname.mkpath
  path.write("---\n#{yaml_frontmatter(frontmatter)}---\n\n#{body}")
end

def base_frontmatter(id, type, extra = {})
  {
    "id" => id,
    "type" => type,
    "schema_version" => "0.1",
    "status" => "active",
    "review_status" => "reviewed",
    "confidence" => 0.8,
    "created" => "2026-08-01",
    "updated" => "2026-08-01",
    "evidence" => [
      { "id" => "artifact_a", "path" => "00_raw_artifacts/text/artifact_a.md" },
      { "id" => "artifact_a", "path" => "00_raw_artifacts/text/artifact_a.md" },
      "00_raw_artifacts/text/scalar.md"
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

def reviewed_fixture(vault)
  write_record(
    vault + "02_notes/memories/memory_a.md",
    base_frontmatter("memory_a", "memory", "created" => Date.new(2026, 8, 1)),
    "# Memory A\n\nA memory body.\n"
  )
  write_record(
    vault + "03_canonical_model/claims/claim_a.md",
    base_frontmatter("claim_a", "claim", "title" => "Claim A"),
    "A claim body.\n"
  )
  write_record(
    vault + "03_canonical_model/relationships/edge_a.md",
    relationship_frontmatter("edge_a", "memory_a", "claim_a"),
    "# Edge A\n\nA relationship body.\n"
  )
  write_record(
    vault + "01_agent_inbox/notes/pending.md",
    base_frontmatter("pending", "memory", "review_status" => "agent_generated", "status" => "draft"),
    "# Pending\n\nShould not appear in graph/report.\n"
  )
end

def review_fixture(vault)
  write_record(
    vault + "01_agent_inbox/notes/note_a.md",
    {
      "id" => "note_a",
      "type" => "note",
      "status" => "draft",
      "review_status" => "agent_generated",
      "confidence" => 0.6,
      "created" => "2026-08-02",
      "source" => { "path" => "00_raw_artifacts/text/source.md" },
      "evidence" => [{ "id" => "artifact_a", "path" => "00_raw_artifacts/text/artifact_a.md" }]
    },
    "# Note A\n\nBody A.\n"
  )
  write_record(
    vault + "01_agent_inbox/claims/claim_pending.md",
    {
      "id" => "claim_pending",
      "type" => "claim",
      "status" => "draft",
      "review_status" => "needs_review",
      "confidence" => 0.9,
      "created" => "2026-08-01",
      "evidence" => [{ "id" => "artifact_a", "path" => "00_raw_artifacts/text/artifact_a.md" }]
    },
    "# Claim Pending\n\nBody.\n"
  )
  write_record(
    vault + "01_agent_inbox/relationships/edge_archived.md",
    {
      "id" => "edge_archived",
      "type" => "relationship",
      "status" => "archived",
      "review_status" => "rejected",
      "created" => "2026-08-03"
    },
    "# Archived\n"
  )
end

def assert_require_is_side_effect_free
  code = <<~RUBY
    require "tmpdir"
    before_argv = ARGV.dup
    before_env = ENV.to_h
    before_threads = Thread.list.length
    require "nous"
    raise "ARGV changed" unless ARGV == before_argv
    raise "ENV changed" unless ENV.to_h == before_env
    raise "threads changed" unless Thread.list.length == before_threads
  RUBY
  env = {
    "RUBYLIB" => LIB.to_s,
    "NOUS_GRAPH_TIME" => "1900-01-01T00:00:00Z",
    "NOUS_REPORT_TIME" => "1900-01-01T00:00:00Z",
    "NOUS_REVIEW_TIME" => "1900-01-01T00:00:00Z"
  }
  stdout, stderr, status = Open3.capture3(env, "ruby", "-e", code, "synthetic-argv")
  assert(status.success?, "require should succeed: #{stderr}")
  assert(stdout.empty?, "require should not write stdout: #{stdout.inspect}")
  assert(stderr.empty?, "require should not write stderr: #{stderr.inspect}")
end

def assert_parse_modes(vault)
  path = vault + "02_notes/memories/memory_a.md"
  error = nil
  begin
    Nous.parse_markdown(path, permitted_classes: [], error_path: "memory_a.md")
  rescue Nous::Error => caught
    error = caught
  end
  assert(error&.code == "NOUS_PARSE_FAILED", "graph parser mode should reject YAML Date")

  frontmatter, body = Nous.parse_markdown(path, permitted_classes: [Date, Time], error_path: "memory_a.md")
  assert(frontmatter["created"] == Date.new(2026, 8, 1), "report parser mode should permit YAML Date")
  assert(body == "\n# Memory A\n\nA memory body.\n", "body extraction should preserve current leading-newline semantics")
end

Dir.mktmpdir("nous-read-core-test-") do |dir|
  tmpdir = Pathname(dir)

  assert_require_is_side_effect_free

  vault = tmpdir + "reviewed-vault"
  reviewed_fixture(vault)
  assert_parse_modes(vault)

  graph_error = nil
  begin
    Nous::Graph.build(vault_root: vault, generated_at: GRAPH_TIME)
  rescue Nous::Error => caught
    graph_error = caught
  end
  assert(graph_error&.code == "NOUS_PARSE_FAILED", "graph core should expose a stable parse error code for YAML Date")

  write_record(
    vault + "02_notes/memories/memory_a.md",
    base_frontmatter("memory_a", "memory", "created" => "2026-08-01"),
    "# Memory A\n\nA memory body.\n"
  )

  graph = Nous::Graph.build(vault_root: vault, generated_at: GRAPH_TIME)
  assert(graph.fetch("generated_at") == GRAPH_TIME, "graph should use explicit generated_at")
  assert(graph.fetch("nodes").map { |node| node.fetch("id") } == ["claim_a", "memory_a"], "graph nodes should be sorted and reviewed-only")
  assert(graph.fetch("edges").map { |edge| edge.fetch("id") } == ["edge_a"], "graph should include connected canonical relationship")
  memory = graph.fetch("nodes").find { |node| node.fetch("id") == "memory_a" }
  assert(memory.fetch("evidence") == [{ "id" => "artifact_a", "path" => "00_raw_artifacts/text/artifact_a.md" }], "graph evidence should accept only hash entries")
  assert(JSON.parse(Nous::Graph.render(graph)) == graph, "graph renderer should emit parseable JSON")

  dangling = vault + "03_canonical_model/relationships/edge_dangling.md"
  write_record(
    dangling,
    relationship_frontmatter("edge_dangling", "memory_a", "missing"),
    "# Dangling\n"
  )
  report = Nous::Report.build(vault_root: vault, generated_at: REPORT_TIME)
  assert(!Nous::Report.render(report).include?("edge_dangling"), "report should filter dangling relationships")
  graph_error = nil
  begin
    Nous::Graph.build(vault_root: vault, generated_at: GRAPH_TIME)
  rescue Nous::Error => caught
    graph_error = caught
  end
  assert(graph_error&.code == "NOUS_INVALID_ENDPOINT", "graph should reject dangling endpoints")

  write_record(
    vault + "02_notes/projects/project_skip.md",
    { "id" => "project_skip", "type" => "project" },
    "# Unsupported\n\nReport should skip unsupported note dirs before validation.\n"
  )
  report = Nous::Report.build(vault_root: vault, generated_at: REPORT_TIME)
  markdown = Nous::Report.render(report)
  assert(markdown.include?("Generated at: #{REPORT_TIME}"), "report should use explicit generated_at")
  assert(markdown.include?("00_raw_artifacts/text/scalar.md"), "report evidence should preserve scalar evidence")
  assert(!markdown.include?("project_skip"), "report should skip unsupported note dirs before validation")
  assert(markdown.include?("edge_a"), "report should render relationship context when both endpoints exist")
  assert(!markdown.include?("edge_dangling"), "report should filter dangling relationships")

  duplicate = vault + "03_canonical_model/claims/claim_duplicate.md"
  write_record(duplicate, base_frontmatter("memory_a", "claim"), "# Duplicate\n")
  duplicate_error = nil
  begin
    Nous::Report.build(vault_root: vault, generated_at: REPORT_TIME)
  rescue Nous::Error => caught
    duplicate_error = caught
  end
  assert(duplicate_error&.code == "NOUS_DUPLICATE_ID", "duplicate IDs should expose stable error code")

  review_vault = tmpdir + "review-vault"
  review_fixture(review_vault)
  items = Nous::Review.list(vault_root: review_vault, sort: "priority")
  assert(items.map(&:relative_path) == [
    "01_agent_inbox/claims/claim_pending.md",
    "01_agent_inbox/notes/note_a.md"
  ], "review list should include pending items only in priority order")
  list_text = Nous::Review.render_list(items)
  assert(list_text.start_with?("priority\tkind\tpath"), "review list renderer should preserve header")
  item = Nous::Review.show(path: review_vault + "01_agent_inbox/notes/note_a.md", vault_root: review_vault)
  before_show = item.path.read
  show_text = Nous::Review.render_show(item)
  assert(show_text.include?("Path: 01_agent_inbox/notes/note_a.md"), "review show should render path")
  assert(show_text.include?("- 00_raw_artifacts/text/source.md"), "review show should render source evidence")
  assert(item.path.read == before_show, "review show should not mutate source")
  report_text = Nous::Review.render_report(Nous::Review.report(vault_root: review_vault, generated_at: REVIEW_TIME))
  assert(report_text.include?("- Pending items: 2"), "review report should count pending items")
  assert(!report_text.include?("edge_archived"), "review report should exclude retired items")
end

puts "nous read core tests ok"
