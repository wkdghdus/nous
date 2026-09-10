#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "open3"
require "pathname"
require "psych"
require "tmpdir"

ROOT = Pathname(__dir__).parent.expand_path
LIB = ROOT + "lib"
FIXED_TIME = "2026-08-08T12:00:00Z"
LATER_TIME = "2026-08-09T13:30:00Z"
REVIEW_TIME = "2026-08-10T14:00:00Z"
GRAPH_TIME = "2026-08-11T15:00:00Z"
CANDIDATE_TYPES = %w[memory value belief project pattern decision person question contradiction].freeze
BASIS_TYPES = %w[user_asserted extractive agent_inferred].freeze

$LOAD_PATH.unshift(LIB.to_s)
require "nous"

$assertions = 0

def assert(condition, message)
  raise message unless condition

  $assertions += 1
end

def assert_equal(expected, actual, message)
  assert(expected == actual, "#{message}: expected #{expected.inspect}, got #{actual.inspect}")
end

def assert_error(code, message)
  yield
  raise "#{message}: expected #{code}"
rescue Nous::Error => error
  raise "#{message}: expected #{code}, got #{error.code} (#{error.message})" unless error.code == code

  $assertions += 1
  error
end

def assert_failure(message)
  begin
    yield
  rescue Nous::Error, RuntimeError => error
    $assertions += 1
    return error
  end

  raise "#{message}: expected failure"
end

def assert_argument_error(message)
  begin
    yield
  rescue ArgumentError => error
    $assertions += 1
    return error
  end

  raise "#{message}: expected ArgumentError"
end

def run_group(name)
  before = $assertions
  yield
  count = $assertions - before
  raise "#{name} made no assertions" if count.zero?

  puts "PASS #{name} (#{count} assertions)"
end

def yaml_frontmatter(data)
  Psych.dump(data).sub(/\A---\n/, "")
end

def write_record(path, frontmatter, body = "# Fixture\n\nSynthetic fixture.\n")
  path.dirname.mkpath
  path.binwrite("---\n#{yaml_frontmatter(frontmatter)}---\n\n#{body}")
end

def parse_record(path)
  frontmatter, body = Nous.parse_markdown(path, permitted_classes: [], error_path: path.basename.to_s)
  [frontmatter, body]
end

def markdown_section(body, heading)
  match = body.match(/^## #{Regexp.escape(heading)}\n\n?(.*?)(?=^## |\z)/m)
  raise "missing Markdown section #{heading}" if match.nil?

  match[1]
end

def result_path(vault, result)
  vault + result.fetch("relative_path")
end

def files(vault, prefix = nil)
  return [] unless vault.exist?

  vault.find.select(&:file?).reject { |path| path.basename.to_s == ".nous.lock" }.select do |path|
    prefix.nil? || path.relative_path_from(vault).to_s.start_with?(prefix)
  end.sort_by(&:to_s)
end

def manifest(vault)
  files(vault).to_h do |path|
    [path.relative_path_from(vault).to_s, Digest::SHA256.file(path.to_s).hexdigest]
  end
end

def assert_no_temps(vault)
  leftovers = vault.find.select { |path| path.basename.to_s.start_with?(".tmp-nous-") }
  assert(leftovers.empty?, "temporary files remain: #{leftovers.map(&:to_s).join(", ")}")
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
    "source" => {
      "type" => "text",
      "path" => "00_raw_artifacts/text/artifact_seed.md",
      "extraction_method" => "manual"
    },
    "evidence" => [{ "id" => "artifact_seed", "path" => "00_raw_artifacts/text/artifact_seed.md" }],
    "counterevidence" => [],
    "tags" => ["synthetic"]
  }.merge(extra)
end

def seed_vault(vault)
  write_record(
    vault + "00_raw_artifacts/text/artifact_seed.md",
    base_frontmatter(
      "artifact_seed",
      "artifact",
      "status" => "draft",
      "review_status" => "needs_review",
      "source" => {
        "type" => "text",
        "path" => "00_raw_artifacts/text/artifact_seed.md",
        "extraction_method" => "manual"
      },
      "evidence" => []
    ),
    "# Seed Artifact\n\n## Observed Content\n\nSynthetic evidence alpha.\n"
  )
  write_record(
    vault + "00_raw_artifacts/text/artifact_counter.md",
    base_frontmatter(
      "artifact_counter",
      "artifact",
      "status" => "draft",
      "review_status" => "needs_review",
      "source" => {
        "type" => "text",
        "path" => "00_raw_artifacts/text/artifact_counter.md",
        "extraction_method" => "manual"
      },
      "evidence" => []
    ),
    "# Counter Artifact\n\n## Observed Content\n\nSynthetic counterevidence beta.\n"
  )
  write_record(vault + "02_notes/memories/reviewed_note.md", base_frontmatter("reviewed_note", "memory"), "# Reviewed Note\n\nReviewed evidence.\n")
  write_record(vault + "03_canonical_model/claims/canonical_claim.md", base_frontmatter("canonical_claim", "claim"), "# Canonical Claim\n\nCanonical evidence.\n")
  write_record(
    vault + "03_canonical_model/relationships/canonical_edge.md",
    base_frontmatter(
      "canonical_edge",
      "relationship",
      "relationship" => { "from" => "reviewed_note", "to" => "canonical_claim", "type" => "supports" }
    )
  )
  write_record(vault + "01_agent_inbox/notes/pending_note.md", base_frontmatter("pending_note", "note", "status" => "draft", "review_status" => "agent_generated"))
  write_record(vault + "01_agent_inbox/claims/pending_claim.md", base_frontmatter("pending_claim", "claim", "status" => "draft", "review_status" => "agent_generated"))
  write_record(
    vault + "01_agent_inbox/relationships/pending_edge.md",
    base_frontmatter(
      "pending_edge",
      "relationship",
      "status" => "draft",
      "review_status" => "agent_generated",
      "relationship" => { "from" => "pending_note", "to" => "pending_claim", "type" => "supports" }
    )
  )
  write_record(vault + "02_notes/memories/retired_note.md", base_frontmatter("retired_note", "memory", "status" => "archived", "review_status" => "rejected"))
  generated = vault + "04_generated/reports/report.md"
  generated.dirname.mkpath
  generated.write("# Derived output\n")
  vault
end

def capture(vault, request_id:, generated_at: FIXED_TIME, **overrides)
  Nous.capture_user_text(
    vault_root: vault,
    request_id: request_id,
    generated_at: generated_at,
    confirmed_user_authored: true,
    user_text: "Synthetic user reflection.\n",
    title: "Synthetic Reflection",
    user_context: "Captured during a synthetic test.",
    represented_date: "2026-08-07",
    **overrides
  )
end

def propose_note(vault, request_id:, generated_at: FIXED_TIME, **overrides)
  Nous.propose_note(
    vault_root: vault,
    request_id: request_id,
    generated_at: generated_at,
    candidate_type: "pattern",
    title: "Synthetic Pattern",
    basis: "extractive",
    primary_evidence_id: "artifact_seed",
    evidence_ids: ["artifact_seed"],
    counterevidence_ids: [],
    source_backed_facts: ["The synthetic source contains alpha."],
    user_context: ["The user labeled this fixture synthetic."],
    tentative_hypotheses: [],
    confidence: 0.75,
    tags: ["synthetic", "m7e"],
    **overrides
  )
end

def propose_claim(vault, request_id:, generated_at: FIXED_TIME, **overrides)
  Nous.propose_claim(
    vault_root: vault,
    request_id: request_id,
    generated_at: generated_at,
    title: "Synthetic Claim",
    statement: "The synthetic source contains alpha.",
    basis: "extractive",
    primary_evidence_id: "artifact_seed",
    evidence_ids: ["artifact_seed"],
    counterevidence_ids: [],
    boundaries: ["This claim applies only to the synthetic fixture."],
    confidence: 0.7,
    tags: ["synthetic"],
    **overrides
  )
end

def propose_relationship(vault, request_id:, generated_at: FIXED_TIME, **overrides)
  Nous.propose_relationship(
    vault_root: vault,
    request_id: request_id,
    generated_at: generated_at,
    from_id: "reviewed_note",
    to_id: "canonical_claim",
    relationship_type: "supports",
    statement: "The reviewed note supports the canonical claim.",
    basis: "extractive",
    primary_evidence_id: "artifact_seed",
    evidence_ids: ["artifact_seed"],
    counterevidence_ids: [],
    confidence: 0.72,
    confidence_rationale: "Both endpoints cite the same synthetic source.",
    tags: ["synthetic"],
    **overrides
  )
end

def assert_generation(path, operation, request_id, generated_at = FIXED_TIME)
  metadata = parse_record(path).first.fetch("generation")
  assert_equal(%w[generated_at input_sha256 interface operation request_id], metadata.keys.sort, "generation keys")
  assert_equal("mcp", metadata.fetch("interface"), "generation interface")
  assert_equal("nous_#{operation}", metadata.fetch("operation"), "generation operation")
  assert_equal(request_id, metadata.fetch("request_id"), "generation request")
  assert(metadata.fetch("input_sha256").match?(/\A[0-9a-f]{64}\z/), "generation digest must be lowercase SHA-256")
  assert_equal(generated_at, metadata.fetch("generated_at"), "generation time")
end

def assert_result(result, type:, lifecycle:, replayed:, review:)
  assert(result.keys.all? { |key| key.is_a?(String) }, "result keys must be strings")
  assert_equal(type, result.fetch("record_type"), "result record type")
  assert_equal(lifecycle, result.fetch("lifecycle_class"), "result lifecycle")
  assert_equal(replayed, result.fetch("replayed"), "result replay flag")
  assert_equal(review, result.fetch("requires_review"), "result review flag")
  assert(result.fetch("record_id").is_a?(String) && !result.fetch("record_id").empty?, "result record ID")
  assert(result.fetch("relative_path").is_a?(String), "result relative path")
  assert(result.fetch("input_sha256").match?(/\A[0-9a-f]{64}\z/), "result digest")
end

def test_schema(tmpdir)
  vault = seed_vault(tmpdir + "schema-vault")
  legacy = files(vault).select { |path| path.extname == ".md" && !path.to_s.include?("04_generated") }
  legacy.each { |path| assert(parse_record(path).first.is_a?(Hash), "legacy fixture must parse: #{path}") }

  result = propose_note(vault, request_id: "schema.note:boundary-1")
  metadata = parse_record(result_path(vault, result)).first
  assert_equal("note", metadata.fetch("type"), "persisted generic note type")
  assert_equal("pattern", metadata.fetch("candidate_type"), "candidate type metadata")
  assert_equal("extractive", metadata.fetch("basis"), "basis metadata")
  assert_generation(result_path(vault, result), "propose_note", "schema.note:boundary-1")

  valid_ids = ["a", "A-Z_0.9:ok", "x" * 128]
  valid_ids.each_with_index { |id, index| capture(vault, request_id: id, title: "Boundary #{index}") }
  ["", "x" * 129, "with space", "slash/value", "back\\value", "line\nbreak", "control\u0001", "unicodé"].each do |id|
    assert_error("NOUS_INVALID_INPUT", "invalid request ID #{id.inspect}") { capture(vault, request_id: id) }
  end
  assert_error("NOUS_INVALID_INPUT", "identity candidate must be rejected") do
    propose_note(vault, request_id: "schema-identity", candidate_type: "identity")
  end
  [nil, "2026-08-08", "not-a-time"].each_with_index do |time, index|
    assert_error("NOUS_INVALID_INPUT", "invalid UTC generation time #{index}") do
      capture(vault, request_id: "schema-time-#{index}", generated_at: time)
    end
  end
  offset_result = capture(vault, request_id: "schema-time-offset", generated_at: "2026-08-08T08:00:00-04:00")
  assert_generation(result_path(vault, offset_result), "capture_user_text", "schema-time-offset", FIXED_TIME)
  fractional_result = capture(vault, request_id: "schema-time-fractional", generated_at: "2026-08-08T12:00:00.123Z")
  assert_generation(result_path(vault, fractional_result), "capture_user_text", "schema-time-fractional", FIXED_TIME)

  capture_result = capture(vault, request_id: "schema-capture")
  capture_metadata = parse_record(result_path(vault, capture_result)).first
  assert_equal("user", capture_metadata.dig("source", "authorship"), "capture authorship")
  assert_equal("mcp", capture_metadata.dig("source", "capture_channel"), "capture channel")
  assert_equal("manual", capture_metadata.dig("source", "extraction_method"), "capture extraction method")

  schema = Psych.safe_load((ROOT + "schemas/note-frontmatter.schema.yaml").read, aliases: false)
  serialized = schema.to_s
  %w[candidate_type basis generation authorship capture_channel].each do |field|
    assert(serialized.include?(field), "schema must document #{field}")
  end
end

def test_idempotency(tmpdir)
  vault = seed_vault(tmpdir + "idempotency-vault")
  creators = {
    "capture_user_text" => ->(request, time = FIXED_TIME) { capture(vault, request_id: request, generated_at: time) },
    "propose_note" => ->(request, time = FIXED_TIME) { propose_note(vault, request_id: request, generated_at: time) },
    "propose_claim" => ->(request, time = FIXED_TIME) { propose_claim(vault, request_id: request, generated_at: time) },
    "propose_relationship" => ->(request, time = FIXED_TIME) { propose_relationship(vault, request_id: request, generated_at: time) }
  }
  creators.each do |operation, call|
    first = call.call("idem-#{operation}")
    bytes = result_path(vault, first).binread
    replay = call.call("idem-#{operation}", LATER_TIME)
    assert_equal(first.fetch("record_id"), replay.fetch("record_id"), "#{operation} replay ID")
    assert_equal(first.fetch("relative_path"), replay.fetch("relative_path"), "#{operation} replay path")
    assert_equal(first.fetch("input_sha256"), replay.fetch("input_sha256"), "#{operation} digest excludes generation time")
    assert_equal(true, replay.fetch("replayed"), "#{operation} replay flag")
    assert_equal(bytes, result_path(vault, replay).binread, "#{operation} replay preserves original bytes/time")
  end

  original = capture(vault, request_id: "idem-conflict")
  before = manifest(vault)
  assert_error("NOUS_IDEMPOTENCY_CONFLICT", "changed text conflicts") do
    capture(vault, request_id: "idem-conflict", user_text: "Changed synthetic text.")
  end
  assert_error("NOUS_IDEMPOTENCY_CONFLICT", "changed title conflicts") do
    capture(vault, request_id: "idem-conflict", title: "Changed title")
  end
  assert_error("NOUS_IDEMPOTENCY_CONFLICT", "cross-operation reuse conflicts") do
    propose_note(vault, request_id: "idem-conflict")
  end
  assert_equal(before, manifest(vault), "idempotency conflicts preserve vault")
  assert(result_path(vault, original).file?, "conflict preserves original record")

  ordered = propose_note(
    vault,
    request_id: "idem-order",
    evidence_ids: %w[artifact_seed reviewed_note],
    primary_evidence_id: "artifact_seed"
  )
  assert_error("NOUS_IDEMPOTENCY_CONFLICT", "evidence order is digest-significant") do
    propose_note(vault, request_id: "idem-order", evidence_ids: %w[reviewed_note artifact_seed], primary_evidence_id: "artifact_seed")
  end
  assert_error("NOUS_IDEMPOTENCY_CONFLICT", "evidence member is digest-significant") do
    propose_note(vault, request_id: "idem-order", evidence_ids: %w[artifact_seed canonical_claim])
  end
  assert(result_path(vault, ordered).file?, "ordered original remains")

  digest_a = propose_claim(vault, request_id: "idem-digest-a").fetch("input_sha256")
  digest_b = propose_claim(vault, request_id: "idem-digest-b", generated_at: LATER_TIME).fetch("input_sha256")
  assert_equal(digest_a, digest_b, "digest excludes request ID and generated time")

  moved = propose_claim(vault, request_id: "idem-moved")
  approved = Nous::ReviewMutation.approve(path: result_path(vault, moved), vault_root: vault, timestamp: REVIEW_TIME)
  moved_replay = propose_claim(vault, request_id: "idem-moved", generated_at: LATER_TIME)
  assert_equal(approved.fetch(:destination_path), moved_replay.fetch("relative_path"), "approved replay finds moved record")
  assert_equal("canonical", moved_replay.fetch("lifecycle_class"), "approved replay lifecycle")
  assert_equal(false, moved_replay.fetch("requires_review"), "approved replay no longer needs review")

  retired = propose_claim(vault, request_id: "idem-retired", title: "Retired Claim")
  Nous::ReviewMutation.reject(path: result_path(vault, retired), vault_root: vault, timestamp: REVIEW_TIME)
  retired_replay = propose_claim(vault, request_id: "idem-retired", title: "Retired Claim")
  assert_equal("retired", retired_replay.fetch("lifecycle_class"), "rejected replay lifecycle")
  assert_equal(true, retired_replay.fetch("replayed"), "rejected replay found")

  duplicate_source = result_path(vault, capture(vault, request_id: "idem-corrupt-duplicate"))
  duplicate_metadata, duplicate_body = parse_record(duplicate_source)
  duplicate_metadata["id"] = "duplicate_generation_record"
  write_record(vault + "00_raw_artifacts/text/duplicate_generation.md", duplicate_metadata, duplicate_body)
  assert_error("NOUS_IDEMPOTENCY_CONFLICT", "duplicate generation request metadata is corruption") do
    capture(vault, request_id: "idem-corrupt-duplicate")
  end

  malformed = result_path(vault, capture(vault, request_id: "idem-corrupt-missing"))
  malformed_metadata, malformed_body = parse_record(malformed)
  malformed_metadata.fetch("generation").delete("input_sha256")
  write_record(malformed, malformed_metadata, malformed_body)
  malformed_before = manifest(vault)
  assert_error("NOUS_PARSE_FAILED", "matching generation missing digest is corruption") do
    capture(vault, request_id: "idem-corrupt-missing")
  end
  assert_equal(malformed_before, manifest(vault), "metadata corruption creates no duplicate")
end

def test_capture(tmpdir)
  vault = seed_vault(tmpdir + "capture-vault")
  raw = "---\r\nkind: still body\r\n## Injected Heading\nUnicode Ω and secret sk-test-synthetic\n"
  result = capture(
    vault,
    request_id: "cap-valid",
    user_text: raw,
    title: "Folder/..\\unsafe\nheading",
    user_context: "Context date 2026-08-07, not observed fact.",
    represented_date: "2026-08-07"
  )
  assert_result(result, type: "artifact", lifecycle: "source_evidence", replayed: false, review: true)
  assert_equal(false, result.fetch("interpretation_created"), "capture creates no interpretation")
  assert_equal(3, files(vault, "00_raw_artifacts/text/").length, "capture creates exactly one additional raw artifact")
  assert_equal(3, files(vault, "01_agent_inbox/").length, "capture creates no inbox record")
  path = result_path(vault, result)
  metadata, body = parse_record(path)
  normalized_raw = raw.gsub("\r\n", "\n").gsub("\r", "\n")
  assert(body.end_with?(normalized_raw), "observed content must preserve exact normalized source bytes")
  assert_equal(normalized_raw, body.split("## Observed Content\n", 2).fetch(1).sub(/\A\n/, ""), "observed section exact readback")
  assert(body.match?(/## User-Provided Context\n\n- Context date 2026-08-07, not observed fact\./), "context remains in its own section")
  assert_equal("none", metadata.fetch("interpretation_level"), "capture interpretation boundary")
  assert(!metadata.key?("facts") && !metadata.key?("hypotheses") && !metadata.key?("relationship"), "capture has no interpretation metadata")
  assert_equal("2026-08-07", metadata.dig("source", "represented_date"), "represented date metadata")
  assert_equal(result.fetch("relative_path"), metadata.dig("source", "path"), "capture source self-path")
  assert(!result.fetch("relative_path").include?("..") && !result.fetch("relative_path").include?("\\"), "title cannot escape output path")
  assert_generation(path, "capture_user_text", "cap-valid")

  source = Nous.read_source_text(vault_root: vault, artifact_id: result.fetch("record_id"), max_chars: 10_000)
  assert_equal(normalized_raw, source.fetch("text"), "M7D source read returns exact captured text")

  fallback_a = capture(vault, request_id: "cap-fallback-a", title: nil, represented_date: nil, user_context: nil)
  fallback_b = capture(vault, request_id: "cap-fallback-b", title: nil, represented_date: nil, user_context: nil)
  assert(!File.basename(fallback_a.fetch("relative_path")).include?("cap-fallback"), "request ID absent from fallback filename")
  assert(!fallback_a.fetch("record_id").include?("cap-fallback"), "request ID absent from generated ID")
  assert(!parse_record(result_path(vault, fallback_a)).last.include?("cap-fallback-a"), "request ID absent from Markdown body")
  assert(fallback_a.fetch("record_id") != fallback_b.fetch("record_id"), "fallback allocation is collision-safe")

  invalid_cases = [
    ["confirmation false", { confirmed_user_authored: false }],
    ["blank text", { user_text: " \n" }],
    ["invalid date", { represented_date: "2026-02-30" }],
    ["oversize", { user_text: "x" * (1024 * 1024 + 1) }]
  ]
  invalid_cases.each_with_index do |(label, kwargs), index|
    before = manifest(vault)
    assert_error("NOUS_INVALID_INPUT", label) { capture(vault, request_id: "cap-invalid-#{index}", **kwargs) }
    assert_equal(before, manifest(vault), "#{label} leaves no record")
  end
  invalid_utf8 = "bad\xFF".b.force_encoding(Encoding::UTF_8)
  assert_error("NOUS_INVALID_INPUT", "invalid UTF-8") { capture(vault, request_id: "cap-invalid-utf8", user_text: invalid_utf8) }
  assert_argument_error("missing authorship confirmation") do
    Nous.capture_user_text(
      vault_root: vault,
      request_id: "cap-missing-confirmation",
      generated_at: FIXED_TIME,
      user_text: "Synthetic text."
    )
  end

  max = capture(vault, request_id: "cap-one-mib", user_text: "x" * (1024 * 1024), title: "One MiB")
  assert(result_path(vault, max).file?, "exactly 1 MiB is accepted")

  legacy_source = tmpdir + "legacy-source.md"
  legacy_source.write("# Legacy Synthetic Input\n\nExisting ingestion remains extractive.\n")
  legacy_vault = tmpdir + "legacy-ingestion-vault"
  legacy = Nous::TextIngestion.ingest(
    source_path: legacy_source,
    vault_root: legacy_vault,
    date: "2026-08-08",
    source_display_base: tmpdir
  )
  assert((legacy_vault + legacy.fetch(:artifact_path)).file?, "existing ingest_text artifact behavior remains")
  assert((legacy_vault + legacy.fetch(:draft_path)).file?, "existing ingest_text still creates its generic draft")
  assert_equal(legacy_source.binread, "# Legacy Synthetic Input\n\nExisting ingestion remains extractive.\n", "existing ingestion leaves source unchanged")
end

def test_evidence(tmpdir)
  eligible = %w[artifact_seed reviewed_note canonical_claim]
  eligible.each do |id|
    vault = seed_vault(tmpdir + "evidence-eligible-#{id}")
    result = propose_claim(vault, request_id: "evidence-#{id}", primary_evidence_id: id, evidence_ids: [id])
    evidence = parse_record(result_path(vault, result)).first.fetch("evidence")
    assert_equal(id, evidence.first.fetch("id"), "eligible #{id} resolves")
    assert(!evidence.first.fetch("path").start_with?("/"), "eligible #{id} path is server-relative")
  end

  ineligible = %w[pending_note pending_claim pending_edge canonical_edge retired_note missing_id]
  ineligible.each do |id|
    vault = seed_vault(tmpdir + "evidence-ineligible-#{id}")
    before = manifest(vault)
    assert_failure("ineligible evidence #{id}") do
      propose_claim(vault, request_id: "evidence-bad-#{id}", primary_evidence_id: id, evidence_ids: [id])
    end
    assert_equal(before, manifest(vault), "ineligible evidence #{id} writes nothing")
  end

  vault = seed_vault(tmpdir + "evidence-structure-vault")
  invalid = [
    ["primary membership", { primary_evidence_id: "reviewed_note", evidence_ids: ["artifact_seed"] }],
    ["duplicate evidence", { evidence_ids: %w[artifact_seed artifact_seed] }],
    ["overlap", { evidence_ids: ["artifact_seed"], counterevidence_ids: ["artifact_seed"] }]
  ]
  invalid.each_with_index do |(label, kwargs), index|
    assert_error("NOUS_INVALID_INPUT", label) { propose_note(vault, request_id: "evidence-structure-#{index}", **kwargs) }
  end

  write_record(vault + "02_notes/memories/duplicate.md", base_frontmatter("reviewed_note", "memory"))
  assert_error("NOUS_DUPLICATE_ID", "duplicate evidence ID") do
    propose_claim(vault, request_id: "evidence-duplicate", primary_evidence_id: "reviewed_note", evidence_ids: ["reviewed_note"])
  end
  parameters = Nous.method(:propose_claim).parameters.map(&:last)
  %i[path output_path id frontmatter markdown].each do |forbidden|
    assert(!parameters.include?(forbidden), "public proposal cannot accept #{forbidden}")
  end
end

def test_notes(tmpdir)
  vault = seed_vault(tmpdir + "notes-vault")
  CANDIDATE_TYPES.each_with_index do |type, index|
    basis = BASIS_TYPES[index % BASIS_TYPES.length]
    hypotheses = basis == "agent_inferred" ? ["A tentative synthetic hypothesis."] : []
    result = propose_note(
      vault,
      request_id: "note-enum-#{type}",
      candidate_type: type,
      title: "#{type.capitalize} Candidate",
      basis: basis,
      tentative_hypotheses: hypotheses
    )
    metadata, body = parse_record(result_path(vault, result))
    assert_result(result, type: "note", lifecycle: "agent_candidate", replayed: false, review: true)
    assert_equal(type, result.fetch("candidate_type"), "result candidate type #{type}")
    assert_equal(["artifact_seed"], result.fetch("evidence_ids"), "result evidence IDs #{type}")
    assert_equal("note", metadata.fetch("type"), "generic persisted type #{type}")
    assert_equal(type, metadata.fetch("candidate_type"), "persisted candidate type #{type}")
    assert_equal(basis == "agent_inferred" ? "medium" : "low", metadata.fetch("interpretation_level"), "basis mapping #{basis}")
    %w[Source-Backed\ Facts User\ Context Tentative\ Hypotheses Relationships Review\ Notes].each do |heading|
      assert_equal(1, body.scan(/^## #{Regexp.escape(heading.tr("\\", ""))}$/).length, "fixed note heading #{heading}")
    end
  end
  assert_error("NOUS_INVALID_INPUT", "identity rejected") { propose_note(vault, request_id: "note-identity", candidate_type: "identity") }
  assert_error("NOUS_INVALID_INPUT", "empty facts rejected") { propose_note(vault, request_id: "note-no-facts", source_backed_facts: []) }
  assert_error("NOUS_INVALID_INPUT", "agent inference requires hypothesis") do
    propose_note(vault, request_id: "note-no-hypothesis", basis: "agent_inferred", tentative_hypotheses: [])
  end

  injection = "---\n## Review Notes\n```ruby\nputs :unsafe\n```\n<li>synthetic</li>"
  result = propose_note(
    vault,
    request_id: "note-injection",
    title: "Unsafe\n## Injected",
    source_backed_facts: [injection],
    user_context: [injection],
    tentative_hypotheses: [injection]
  )
  body = parse_record(result_path(vault, result)).last
  assert_equal(1, body.scan(/^## Review Notes$/).length, "note injection cannot create fixed sibling section")
  assert(body.include?("  ## Review Notes"), "injected heading is indented inside a list item")
  assert(!result.fetch("relative_path").include?("Injected"), "multiline title cannot control filename")

  graph = Nous::Graph.build(vault_root: vault, generated_at: GRAPH_TIME)
  report = Nous::Report.build(vault_root: vault, generated_at: GRAPH_TIME)
  pending_ids = files(vault, "01_agent_inbox/notes/").map { |path| parse_record(path).first["id"] }
  graph_ids = graph.fetch("nodes").map { |node| node.fetch("id") }
  report_text = Nous::Report.render(report)
  assert((pending_ids & graph_ids).empty?, "pending notes excluded from graph")
  assert(pending_ids.none? { |id| report_text.include?(id) }, "pending notes excluded from report")

  approved = propose_note(vault, request_id: "note-approve", candidate_type: "memory", title: "Approved Note")
  assert_error("NOUS_INVALID_INPUT", "note approval still requires explicit mapping") do
    Nous::ReviewMutation.approve(path: result_path(vault, approved), vault_root: vault, timestamp: REVIEW_TIME)
  end
  approval = Nous::ReviewMutation.approve(path: result_path(vault, approved), vault_root: vault, timestamp: REVIEW_TIME, note_type: "memory")
  approved_path = vault + approval.fetch(:destination_path)
  assert_equal("memory", parse_record(approved_path).first.fetch("type"), "explicit review maps note type")
  assert(parse_record(approved_path).first.key?("generation"), "approval retains generation metadata")
end

def test_claims(tmpdir)
  vault = seed_vault(tmpdir + "claims-vault")
  result = propose_claim(
    vault,
    request_id: "claim-valid",
    evidence_ids: %w[artifact_seed reviewed_note],
    counterevidence_ids: ["artifact_counter"],
    boundaries: ["Boundary remains separate."],
    statement: "Synthetic statement."
  )
  assert_result(result, type: "claim", lifecycle: "agent_candidate", replayed: false, review: true)
  metadata, body = parse_record(result_path(vault, result))
  assert_equal("draft", metadata.fetch("status"), "claim draft status")
  assert_equal("agent_generated", metadata.fetch("review_status"), "claim review status")
  assert_equal(%w[artifact_seed reviewed_note], result.fetch("evidence_ids"), "claim ordered evidence result")
  assert(body.match?(/## Statement\n\n- Synthetic statement\./), "claim statement section")
  assert(body.match?(/## Boundaries\n\n- Boundary remains separate\./), "claim boundary section")
  assert(!markdown_section(body, "Statement").include?("Boundary remains separate"), "boundaries are not appended to statement")
  assert_equal(%w[artifact_seed reviewed_note], metadata.fetch("evidence").map { |entry| entry.fetch("id") }, "persisted evidence order")
  assert_equal(["artifact_counter"], metadata.fetch("counterevidence").map { |entry| entry.fetch("id") }, "persisted counterevidence order")
  %w[Statement Evidence Counterevidence Boundaries Review\ Decision].each do |heading|
    assert_equal(1, body.scan(/^## #{Regexp.escape(heading.tr("\\", ""))}$/).length, "fixed claim heading #{heading}")
  end

  ["", "x" * 1001].each_with_index do |statement, index|
    assert_error("NOUS_INVALID_INPUT", "invalid statement #{index}") do
      propose_claim(vault, request_id: "claim-statement-#{index}", statement: statement)
    end
  end
  injection = "---\n## Evidence\n<script>synthetic</script>"
  injected = propose_claim(vault, request_id: "claim-injection", statement: injection, boundaries: [injection])
  injected_body = parse_record(result_path(vault, injected)).last
  assert_equal(1, injected_body.scan(/^## Evidence$/).length, "claim injection cannot create evidence section")

  rejected = propose_claim(vault, request_id: "claim-reject", title: "Rejected Candidate")
  Nous::ReviewMutation.reject(path: result_path(vault, rejected), vault_root: vault, timestamp: REVIEW_TIME)
  replay = propose_claim(vault, request_id: "claim-reject", title: "Rejected Candidate")
  assert_equal("retired", replay.fetch("lifecycle_class"), "rejected claim replay")
  assert_equal(1, files(vault).count { |path| parse_record(path).first.dig("generation", "request_id") == "claim-reject" rescue false }, "rejection creates no duplicate")
end

def test_relationships(tmpdir)
  vault = seed_vault(tmpdir + "relationships-vault")
  Nous::SUPPORTED_RELATIONSHIP_TYPES.each do |type|
    result = propose_relationship(vault, request_id: "rel-enum-#{type}", relationship_type: type)
    metadata = parse_record(result_path(vault, result)).first
    assert_equal(type, result.fetch("relationship_type"), "relationship result enum #{type}")
    assert_equal(type, metadata.dig("relationship", "type"), "persisted relationship enum #{type}")
    assert_equal(true, result.fetch("approval_ready"), "reviewed-to-canonical #{type} readiness")
    assert_equal(true, result.dig("endpoints", "from", "approval_ready"), "from readiness #{type}")
    assert_equal(true, result.dig("endpoints", "to", "approval_ready"), "to readiness #{type}")
  end
  assert_error("NOUS_INVALID_INPUT", "unsupported relationship type") do
    propose_relationship(vault, request_id: "rel-unsupported", relationship_type: "owns")
  end
  assert_error("NOUS_INVALID_INPUT", "self-loop") do
    propose_relationship(vault, request_id: "rel-self", from_id: "reviewed_note", to_id: "reviewed_note")
  end

  invalid_endpoints = [
    ["missing", "missing_endpoint"],
    ["artifact", "artifact_seed"],
    ["relationship", "canonical_edge"],
    ["retired", "retired_note"]
  ]
  invalid_endpoints.each_with_index do |(label, endpoint), index|
    assert_failure("#{label} relationship endpoint") do
      propose_relationship(vault, request_id: "rel-invalid-#{index}", from_id: endpoint)
    end
  end

  pending = propose_relationship(
    vault,
    request_id: "rel-pending",
    from_id: "pending_note",
    to_id: "pending_claim",
    evidence_ids: ["artifact_seed"],
    primary_evidence_id: "artifact_seed"
  )
  assert_equal(false, pending.fetch("approval_ready"), "pending endpoint relationship not ready")
  assert_equal("agent_candidate", pending.dig("endpoints", "from", "lifecycle_class"), "pending from lifecycle")
  assert_equal("agent_candidate", pending.dig("endpoints", "to", "lifecycle_class"), "pending to lifecycle")
  assert_equal(["artifact_seed"], pending.fetch("evidence_ids"), "endpoints are not implicit evidence")
  assert_error("NOUS_REVIEW_REQUIRED", "pending endpoints block relationship approval") do
    Nous::ReviewMutation.approve(path: result_path(vault, pending), vault_root: vault, timestamp: REVIEW_TIME)
  end

  mixed = propose_relationship(vault, request_id: "rel-mixed", from_id: "pending_note", to_id: "canonical_claim")
  assert_equal(false, mixed.fetch("approval_ready"), "pending-to-reviewed is not ready")

  progressive_note = propose_note(vault, request_id: "rel-progress-note", candidate_type: "memory", title: "Progress Note")
  progressive_claim = propose_claim(vault, request_id: "rel-progress-claim", title: "Progress Claim")
  progressive = propose_relationship(
    vault,
    request_id: "rel-progress-edge",
    from_id: progressive_note.fetch("record_id"),
    to_id: progressive_claim.fetch("record_id")
  )
  assert_error("NOUS_REVIEW_REQUIRED", "both progressive endpoints pending") do
    Nous::ReviewMutation.approve(path: result_path(vault, progressive), vault_root: vault, timestamp: REVIEW_TIME)
  end
  Nous::ReviewMutation.approve(path: result_path(vault, progressive_note), vault_root: vault, timestamp: REVIEW_TIME, note_type: "memory")
  assert_error("NOUS_REVIEW_REQUIRED", "one progressive endpoint pending") do
    Nous::ReviewMutation.approve(path: result_path(vault, progressive), vault_root: vault, timestamp: REVIEW_TIME)
  end
  Nous::ReviewMutation.approve(path: result_path(vault, progressive_claim), vault_root: vault, timestamp: REVIEW_TIME)
  edge_approval = Nous::ReviewMutation.approve(path: result_path(vault, progressive), vault_root: vault, timestamp: REVIEW_TIME)
  graph = Nous::Graph.build(vault_root: vault, generated_at: GRAPH_TIME)
  assert(graph.fetch("edges").any? { |edge| edge.fetch("id") == progressive.fetch("record_id") }, "approved relationship appears as graph edge")
  assert((vault + edge_approval.fetch(:destination_path)).file?, "approved relationship moved canonical")

  retiring_note = propose_note(vault, request_id: "rel-retire-note", candidate_type: "memory", title: "Retire Endpoint")
  retiring_claim = propose_claim(vault, request_id: "rel-retire-claim", title: "Retire Other Endpoint")
  retiring_edge = propose_relationship(
    vault,
    request_id: "rel-retire-edge",
    from_id: retiring_note.fetch("record_id"),
    to_id: retiring_claim.fetch("record_id")
  )
  Nous::ReviewMutation.reject(path: result_path(vault, retiring_note), vault_root: vault, timestamp: REVIEW_TIME)
  assert_failure("retired endpoint blocks approval") do
    Nous::ReviewMutation.approve(path: result_path(vault, retiring_edge), vault_root: vault, timestamp: REVIEW_TIME)
  end
end

def test_rendering(tmpdir)
  vault = seed_vault(tmpdir + "rendering-vault")
  hostile = "---\r\n## Review Decision\r<script>synthetic</script> ` ``` - item [link](file:///tmp/x)"
  note = propose_note(
    vault,
    request_id: "render-note",
    title: hostile,
    source_backed_facts: [hostile],
    user_context: [hostile],
    tentative_hypotheses: [hostile]
  )
  claim = propose_claim(vault, request_id: "render-claim", title: hostile, statement: hostile, boundaries: [hostile])
  relationship = propose_relationship(
    vault,
    request_id: "render-rel",
    statement: hostile,
    confidence_rationale: hostile,
    tags: ["synthetic"]
  )
  expected_headings = {
    note => %w[Source-Backed\ Facts User\ Context Tentative\ Hypotheses Relationships Review\ Notes],
    claim => %w[Statement Evidence Counterevidence Boundaries Review\ Decision],
    relationship => %w[Relationship\ Statement From To Evidence Confidence\ Rationale Review\ Decision]
  }
  expected_headings.each do |result, headings|
    metadata, body = parse_record(result_path(vault, result))
    assert(metadata.is_a?(Hash), "hostile content leaves valid YAML")
    headings.each do |heading|
      normalized = heading.tr("\\", "")
      assert_equal(1, body.scan(/^## #{Regexp.escape(normalized)}$/).length, "#{result.fetch("record_type")} fixed heading #{normalized}")
    end
    assert(body.include?("  ## Review Decision") || result.equal?(note), "hostile heading remains indented content")
  end
  assert(!result_path(vault, note).basename.to_s.include?(".."), "path-like title cannot control path")

  long_secret = "sk-test-" + ("!" * 2_100)
  error = assert_error("NOUS_INVALID_INPUT", "long repeated punctuation bound") do
    propose_relationship(vault, request_id: "render-too-long", confidence_rationale: long_secret)
  end
  assert(!error.message.include?(long_secret), "validation error does not echo secret-shaped content")
  assert_error("NOUS_INVALID_INPUT", "NUL rejected") do
    propose_note(vault, request_id: "render-nul", source_backed_facts: ["bad\u0000value"])
  end
end

def child_call(operation, vault, request_id, writer)
  reader, pipe_writer = IO.pipe
  pid = fork do
    reader.close
    begin
      result = send(operation, vault, request_id: request_id)
      Marshal.dump(["ok", result], pipe_writer)
    rescue StandardError => error
      Marshal.dump(["error", error.class.name, error.respond_to?(:code) ? error.code : nil, error.message], pipe_writer)
    ensure
      pipe_writer.close
    end
  end
  pipe_writer.close
  writer << [pid, reader]
end

def collect_children(children)
  children.map do |pid, reader|
    value = Marshal.load(reader)
    reader.close
    Process.wait(pid)
    value
  end
end

def generation_count(vault, request_id)
  files(vault).count do |path|
    next false unless path.extname == ".md"

    parse_record(path).first.dig("generation", "request_id") == request_id
  rescue Nous::Error
    false
  end
end

def test_concurrency_and_failures(tmpdir)
  %i[capture propose_note propose_claim propose_relationship].each do |operation|
    vault = seed_vault(tmpdir + "concurrent-#{operation}")
    children = []
    2.times { child_call(operation, vault, "conc-identical-#{operation}", children) }
    results = collect_children(children)
    assert(results.all? { |row| row.first == "ok" }, "concurrent #{operation} calls succeed: #{results.inspect}")
    payloads = results.map { |row| row.fetch(1) }
    assert_equal(1, payloads.map { |row| row.fetch("record_id") }.uniq.length, "concurrent #{operation} one ID")
    assert_equal([false, true], payloads.map { |row| row.fetch("replayed") }.sort_by(&:to_s), "concurrent #{operation} create/replay")
    assert_equal(1, generation_count(vault, "conc-identical-#{operation}"), "concurrent #{operation} one record")
    assert_no_temps(vault)
  end

  vault = seed_vault(tmpdir + "concurrent-slug-vault")
  children = []
  child_call(:propose_note, vault, "conc-slug-a", children)
  child_call(:propose_note, vault, "conc-slug-b", children)
  results = collect_children(children)
  paths = results.map { |row| row.fetch(1).fetch("relative_path") }
  assert_equal(2, paths.uniq.length, "different requests with same title receive distinct paths")
  assert(paths.all? { |path| (vault + path).file? }, "both same-title results exist")

  failure_vault = seed_vault(tmpdir + "failure-vault")
  {
    "before" => :before_stage,
    "after-stage" => :after_stage
  }.each do |label, callback|
    request = "fail-#{label}"
    before = manifest(failure_vault)
    assert_failure("failure #{label}") do
      propose_claim(failure_vault, request_id: request, callback => -> { raise "synthetic #{label} failure" })
    end
    assert_equal(before, manifest(failure_vault), "failure #{label} leaves no finalized record")
    assert_no_temps(failure_vault)
    retry_result = propose_claim(failure_vault, request_id: request)
    assert_equal(false, retry_result.fetch("replayed"), "failure #{label} retry creates")
  end

  finalized_request = "fail-after-finalize"
  assert_failure("failure after finalize") do
    propose_claim(failure_vault, request_id: finalized_request, after_finalize: -> { raise "synthetic response failure" })
  end
  assert_equal(1, generation_count(failure_vault, finalized_request), "after-finalize failure retains one final record")
  finalized_replay = propose_claim(failure_vault, request_id: finalized_request)
  assert_equal(true, finalized_replay.fetch("replayed"), "after-finalize retry replays")
  assert_equal(1, generation_count(failure_vault, finalized_request), "after-finalize retry creates no duplicate")
  assert_no_temps(failure_vault)

  lock_vault = seed_vault(tmpdir + "lock-timeout-vault")
  child_in, child_out, child_err, waiter = Open3.popen3(
    { "RUBYLIB" => LIB.to_s },
    "ruby", "-e",
    'require "nous"; Nous::VaultLock.new(vault_root: ARGV.fetch(0), timeout: 1).with_exclusive { puts "locked"; STDOUT.flush; sleep 1 }',
    lock_vault.to_s
  )
  child_in.close
  assert_equal("locked", child_out.gets&.strip, "lock holder started")
  before = manifest(lock_vault)
  assert_error("NOUS_LOCK_TIMEOUT", "candidate lock timeout") do
    propose_claim(lock_vault, request_id: "fail-lock-timeout", lock_timeout: 0.05)
  end
  assert_equal(before, manifest(lock_vault), "lock timeout writes no record/idempotency metadata")
  waiter.value
  assert_equal("", child_err.read, "lock holder stderr")

  bad_vault = seed_vault(tmpdir + "failure-evidence-vault")
  before = manifest(bad_vault)
  assert_failure("invalid evidence after lock") do
    propose_claim(bad_vault, request_id: "fail-evidence", primary_evidence_id: "missing", evidence_ids: ["missing"])
  end
  assert_equal(before, manifest(bad_vault), "invalid evidence writes no file")
  assert_no_temps(bad_vault)
end

def test_direct_e2e_and_static(tmpdir)
  vault = seed_vault(tmpdir + "e2e-vault")
  original_seed = (vault + "00_raw_artifacts/text/artifact_seed.md").binread
  captured_text = "I noticed a repeatable synthetic pattern.\n"
  captured = capture(vault, request_id: "e2e-capture", user_text: captured_text, title: "E2E Source")
  readback = Nous.read_source_text(vault_root: vault, artifact_id: captured.fetch("record_id"), max_chars: 10_000)
  assert_equal(captured_text, readback.fetch("text"), "E2E exact source readback")

  evidence_id = captured.fetch("record_id")
  note = propose_note(
    vault,
    request_id: "e2e-note",
    candidate_type: "pattern",
    title: "E2E Pattern",
    primary_evidence_id: evidence_id,
    evidence_ids: [evidence_id]
  )
  claim = propose_claim(
    vault,
    request_id: "e2e-claim",
    title: "E2E Claim",
    primary_evidence_id: evidence_id,
    evidence_ids: [evidence_id]
  )
  edge = propose_relationship(
    vault,
    request_id: "e2e-edge",
    from_id: note.fetch("record_id"),
    to_id: claim.fetch("record_id"),
    primary_evidence_id: evidence_id,
    evidence_ids: [evidence_id]
  )
  assert_equal(false, edge.fetch("approval_ready"), "E2E pending edge readiness")

  pending_ids = [note, claim, edge].map { |result| result.fetch("record_id") }
  pending_graph = Nous::Graph.build(vault_root: vault, generated_at: GRAPH_TIME)
  pending_report = Nous::Report.render(Nous::Report.build(vault_root: vault, generated_at: GRAPH_TIME))
  assert((pending_ids & pending_graph.fetch("nodes").map { |node| node.fetch("id") }).empty?, "E2E pending nodes excluded")
  assert(pending_graph.fetch("edges").none? { |item| item.fetch("id") == edge.fetch("record_id") }, "E2E pending edge excluded")
  assert(pending_ids.none? { |id| pending_report.include?(id) }, "E2E pending records excluded from report")

  note_approval = Nous::ReviewMutation.approve(path: result_path(vault, note), vault_root: vault, timestamp: REVIEW_TIME, note_type: "pattern")
  claim_approval = Nous::ReviewMutation.approve(path: result_path(vault, claim), vault_root: vault, timestamp: REVIEW_TIME)
  edge_retry = propose_relationship(
    vault,
    request_id: "e2e-edge",
    from_id: note.fetch("record_id"),
    to_id: claim.fetch("record_id"),
    primary_evidence_id: evidence_id,
    evidence_ids: [evidence_id]
  )
  assert_equal(true, edge_retry.fetch("replayed"), "E2E relationship replay")
  assert_equal(true, edge_retry.fetch("approval_ready"), "E2E replay recomputes endpoint readiness")
  edge_approval = Nous::ReviewMutation.approve(path: result_path(vault, edge_retry), vault_root: vault, timestamp: REVIEW_TIME)
  edge_moved_replay = propose_relationship(
    vault,
    request_id: "e2e-edge",
    from_id: note.fetch("record_id"),
    to_id: claim.fetch("record_id"),
    primary_evidence_id: evidence_id,
    evidence_ids: [evidence_id]
  )
  assert_equal(edge_approval.fetch(:destination_path), edge_moved_replay.fetch("relative_path"), "E2E edge moved replay")
  assert_equal("canonical", edge_moved_replay.fetch("lifecycle_class"), "E2E edge replay lifecycle")

  graph = Nous::Graph.build(vault_root: vault, generated_at: GRAPH_TIME)
  report = Nous::Report.render(Nous::Report.build(vault_root: vault, generated_at: GRAPH_TIME))
  assert(graph.fetch("nodes").any? { |item| item.fetch("id") == note.fetch("record_id") }, "E2E approved note graph node")
  assert(graph.fetch("nodes").any? { |item| item.fetch("id") == claim.fetch("record_id") }, "E2E approved claim graph node")
  assert(graph.fetch("edges").any? { |item| item.fetch("id") == edge.fetch("record_id") }, "E2E approved graph edge")
  assert(report.include?(note.fetch("record_id")) && report.include?(claim.fetch("record_id")), "E2E approved report entries")
  assert((vault + note_approval.fetch(:destination_path)).file?, "E2E note reviewed destination")
  assert((vault + claim_approval.fetch(:destination_path)).file?, "E2E claim canonical destination")
  assert((vault + edge_approval.fetch(:destination_path)).file?, "E2E edge canonical destination")

  note_replay = propose_note(
    vault,
    request_id: "e2e-note",
    candidate_type: "pattern",
    title: "E2E Pattern",
    primary_evidence_id: evidence_id,
    evidence_ids: [evidence_id]
  )
  claim_replay = propose_claim(
    vault,
    request_id: "e2e-claim",
    title: "E2E Claim",
    primary_evidence_id: evidence_id,
    evidence_ids: [evidence_id]
  )
  assert_equal(note_approval.fetch(:destination_path), note_replay.fetch("relative_path"), "E2E note moved replay")
  assert_equal(claim_approval.fetch(:destination_path), claim_replay.fetch("relative_path"), "E2E claim moved replay")
  assert_equal(original_seed, (vault + "00_raw_artifacts/text/artifact_seed.md").binread, "E2E seed evidence unchanged")
  assert_equal(captured_text, Nous.read_source_text(vault_root: vault, artifact_id: evidence_id, max_chars: 10_000).fetch("text"), "E2E captured evidence unchanged")

  public_methods = %i[capture_user_text propose_note propose_claim propose_relationship]
  common_optional = %i[lock_timeout before_stage after_stage after_finalize]
  expected_parameters = {
    capture_user_text: %i[
      vault_root request_id generated_at confirmed_user_authored user_text title user_context represented_date
    ] + common_optional,
    propose_note: %i[
      vault_root request_id generated_at candidate_type title basis primary_evidence_id evidence_ids
      counterevidence_ids source_backed_facts user_context tentative_hypotheses confidence tags
    ] + common_optional,
    propose_claim: %i[
      vault_root request_id generated_at title statement basis primary_evidence_id evidence_ids
      counterevidence_ids boundaries confidence tags
    ] + common_optional,
    propose_relationship: %i[
      vault_root request_id generated_at from_id to_id relationship_type statement basis primary_evidence_id
      evidence_ids counterevidence_ids confidence confidence_rationale tags
    ] + common_optional
  }
  forbidden_inputs = %i[path output_path filename id record_id frontmatter markdown body]
  public_methods.each do |method_name|
    parameters = Nous.method(method_name).parameters.map(&:last)
    assert_equal(expected_parameters.fetch(method_name).sort, parameters.sort, "#{method_name} exact public inputs")
    %i[vault_root request_id generated_at].each do |required|
      assert(parameters.include?(required), "#{method_name} includes #{required}")
    end
    forbidden_inputs.each { |name| assert(!parameters.include?(name), "#{method_name} excludes agent-controlled #{name}") }
  end
  candidate_sources = public_methods.map { |name| Pathname(Nous.method(name).source_location.fetch(0)) }
  candidate_sources.concat(Pathname.glob((ROOT + "lib/nous/{candidate*,idempotency}.rb").to_s))
  candidate_sources.uniq!
  source_text = candidate_sources.map(&:read).join("\n")
  forbidden = /require\s+["']mcp["']|\bMCP::|Net::HTTP|TCPSocket|OpenAI|Anthropic|Gemfile|SQLite|PG::/
  assert(!source_text.match?(forbidden), "candidate core has no MCP/network/model/provider/database dependency")
  assert(!Object.const_defined?(:MCP), "candidate tests load no MCP classes")
  assert(!(ROOT + "Gemfile").exist?, "candidate writes add no Gemfile")
end

Dir.mktmpdir("nous-candidate-writes-test-") do |directory|
  tmpdir = Pathname(directory)
  run_group("SCHEMA-E") { test_schema(tmpdir) }
  run_group("IDEM-E") { test_idempotency(tmpdir) }
  run_group("CAP-E") { test_capture(tmpdir) }
  run_group("EVID-E") { test_evidence(tmpdir) }
  run_group("NOTE-E") { test_notes(tmpdir) }
  run_group("CLAIM-E") { test_claims(tmpdir) }
  run_group("REL-E") do
    test_relationships(tmpdir)
    test_direct_e2e_and_static(tmpdir)
  end
  run_group("RENDER-E") { test_rendering(tmpdir) }
  run_group("CONC-E") { test_concurrency_and_failures(tmpdir) }
end

puts "PASS nous candidate writes (#{$assertions} assertions)"
