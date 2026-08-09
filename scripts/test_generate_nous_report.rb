#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"
require "psych"
require "tmpdir"

ROOT = Pathname(__dir__).parent.expand_path
SCRIPT = ROOT + "scripts/generate_nous_report.rb"
REPORT_TIME = "2026-08-08T22:33:53Z"
LONG_EXCERPT = "#{"Focused report text " * 20}tail"
SECTION_HEADINGS = [
  "## Core Values",
  "## Beliefs",
  "## Patterns",
  "## Memories",
  "## Contradictions",
  "## Questions",
  "## Source-Backed Claims"
].freeze

def run_report(vault, output = nil, env: {})
  command_env = { "NOUS_REPORT_TIME" => REPORT_TIME }.merge(env)
  command = ["ruby", SCRIPT.to_s, "--vault-root", vault.to_s]
  command.concat(["--output", output.to_s]) if output
  stdout, stderr, status = Open3.capture3(command_env, *command)
  [stdout, stderr, status]
end

def assert(condition, message)
  raise message unless condition
end

def assert_no_repo_vault_writes
  repo_vault = ROOT + "vault"
  return unless repo_vault.directory?

  markers = ["value_lucid_work", "belief_context_matters", "Pending Report Leak"]
  leaked = repo_vault.find.select(&:file?).select do |path|
    text = path.binread
    markers.any? { |marker| path.to_s.include?(marker) || text.include?(marker) }
  end
  assert(leaked.empty?, "generate_nous_report fixtures leaked into repo vault: #{leaked.map(&:to_s).inspect}")
end

def assert_success(status, stderr)
  assert(status.success?, "expected command to pass: #{stderr}")
end

def assert_failure(status, stderr, expected)
  assert(!status.success?, "expected command to fail")
  assert(stderr.include?(expected), "expected error to include #{expected.inspect}, got #{stderr.inspect}")
end

def assert_includes(text, expected, message)
  assert(text.include?(expected), "#{message}: missing #{expected.inspect}")
end

def assert_absent(text, unexpected, message)
  assert(!text.include?(unexpected), "#{message}: found #{unexpected.inspect}")
end

def assert_ordered(text, values, message)
  positions = values.map { |value| text.index(value) }
  assert(positions.none?(&:nil?), "#{message}: missing one of #{values.inspect}")
  assert(positions == positions.sort, "#{message}: order was #{positions.inspect}")
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
    "updated" => "2026-08-02",
    "evidence" => [
      { "id" => "artifact_reflection", "path" => "00_raw_artifacts/text/reflection.md" },
      { "id" => "artifact_reflection", "path" => "00_raw_artifacts/text/reflection.md" },
      "00_raw_artifacts/writing/journal.md",
      { "id" => "", "path" => "ignored-empty-id.md" },
      { "id" => "ignored-empty-path", "path" => "" },
      "00_raw_artifacts/writing/journal.md"
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

def complete_fixture(vault)
  write_record(
    vault + "02_notes/values/value_lucid_work.md",
    base_frontmatter("value_lucid_work", "value", "title" => "Lucid Work", "created" => "2026-08-01"),
    "# Clear Work\n\nI value tools that make decisions easier to inspect.\n"
  )
  write_record(
    vault + "02_notes/beliefs/belief_context_matters.md",
    base_frontmatter("belief_context_matters", "belief", "title" => "Context Matters", "created" => "2026-08-02"),
    "#{LONG_EXCERPT}\n"
  )
  write_record(
    vault + "02_notes/patterns/pattern_evening_review.md",
    base_frontmatter("pattern_evening_review", "pattern", "created" => "2026-08-03"),
    "# Evening Review\n\nReviewing at night helps connect details.\n"
  )
  write_record(
    vault + "02_notes/memories/memory_first_report.md",
    base_frontmatter("memory_first_report", "memory", "created" => "2026-08-04"),
    "# First Report\n\nThe first report should stay source backed.\n"
  )
  write_record(
    vault + "02_notes/contradictions/contradiction_speed_care.md",
    base_frontmatter("contradiction_speed_care", "contradiction", "created" => "2026-08-05"),
    "# Speed and Care\n\nI want speed and careful review at the same time.\n"
  )
  write_record(
    vault + "02_notes/questions/question_future_scope.md",
    base_frontmatter("question_future_scope", "question", "created" => "2026-08-06"),
    "# Future Scope\n\nWhich future features should wait?\n"
  )
  write_record(
    vault + "03_canonical_model/claims/claim_source_backed.md",
    base_frontmatter("claim_source_backed", "claim", "title" => "Reports Stay Auditable", "created" => "2026-08-07"),
    "Reports should expose evidence instead of hiding it.\n"
  )
  write_record(
    vault + "03_canonical_model/relationships/edge_memory_claim.md",
    relationship_frontmatter("edge_memory_claim", "memory_first_report", "claim_source_backed", "supports"),
    "# Relationship\n\nThe memory supports the claim.\n"
  )
  write_record(
    vault + "03_canonical_model/relationships/edge_dangling.md",
    relationship_frontmatter("edge_dangling", "memory_first_report", "missing_record", "supports"),
    "# Dangling\n\nThis must not render.\n"
  )

  write_record(
    vault + "01_agent_inbox/notes/note_pending.md",
    base_frontmatter("note_pending", "memory", "status" => "draft", "review_status" => "agent_generated"),
    "# Pending Report Leak\n\nThis must not render.\n"
  )
  write_record(
    vault + "02_notes/memories/memory_rejected.md",
    base_frontmatter("memory_rejected", "memory", "review_status" => "rejected"),
    "# Rejected Report Leak\n\nThis must not render.\n"
  )
  write_record(
    vault + "02_notes/memories/memory_deprecated.md",
    base_frontmatter("memory_deprecated", "memory", "review_status" => "deprecated"),
    "# Deprecated Report Leak\n\nThis must not render.\n"
  )
  write_record(
    vault + "02_notes/memories/memory_archived.md",
    base_frontmatter("memory_archived", "memory", "status" => "archived"),
    "# Archived Report Leak\n\nThis must not render.\n"
  )
  write_record(
    vault + "02_notes/people/person_unsupported.md",
    base_frontmatter("person_unsupported", "person"),
    "# Unsupported Report Leak\n\nThis must not render.\n"
  )
  write_record(
    vault + "02_notes/projects/project_malformed_unsupported.md",
    { "id" => "project_malformed_unsupported", "type" => "project" },
    "# Malformed Unsupported Report Leak\n\nThis must not be validated or rendered.\n"
  )
end

def section_body(report, heading)
  match = report.match(/^#{Regexp.escape(heading)}\n\n(.*?)(?=^## |\z)/m)
  raise "missing section #{heading}" unless match

  match[1]
end

def case_complete_report_renders_contract(tmpdir)
  vault = tmpdir + "complete-vault"
  output = tmpdir + "complete.md"
  complete_fixture(vault)

  stdout, stderr, status = run_report(vault, output)
  assert_success(status, stderr)
  assert(stdout.include?("report:"), "command should print report output path")

  report = output.read
  assert(report.start_with?("# Nous Report\n"), "report should start with title")
  assert_includes(report, REPORT_TIME, "report should expose fixed generated timestamp")
  assert(report.match?(/reviewed.*canonical|canonical.*reviewed/i), "report should describe reviewed and canonical source boundary")
  assert_ordered(report, SECTION_HEADINGS, "fixed sections should render in order")

  [
    "value_lucid_work",
    "belief_context_matters",
    "pattern_evening_review",
    "memory_first_report",
    "contradiction_speed_care",
    "question_future_scope"
  ].each { |id| assert_includes(report, id, "reviewed notes should render") }
  assert_includes(report, "Clear Work", "H1 should be preferred as note label")
  assert_includes(report, "Context Matters", "frontmatter title should be used when there is no H1")
  assert_includes(report, "Source: 02_notes/values/value_lucid_work.md", "source path should be vault-relative")
  assert_includes(report, "Confidence: 0.8", "confidence should render when present")
  assert_includes(report, "I value tools that make decisions easier to inspect.", "excerpt should render")
  assert_includes(report, "00_raw_artifacts/text/reflection.md", "hash evidence path should render")
  assert_includes(report, "00_raw_artifacts/writing/journal.md", "scalar evidence path should render")
  assert(report.scan("00_raw_artifacts/text/reflection.md").length < 8, "duplicate evidence should be deduplicated per rendered record")
  assert(report.scan("00_raw_artifacts/writing/journal.md").length < 8, "duplicate scalar evidence should be deduplicated per rendered record")
  assert_absent(report, "ignored-empty-id.md", "blank evidence IDs should be ignored")
  assert_absent(report, "ignored-empty-path", "blank evidence paths should be ignored")

  belief_section = section_body(report, "## Beliefs")
  assert_includes(belief_section, "Focused report text", "bounded excerpt should render")
  assert(belief_section.length < LONG_EXCERPT.length + 900, "long body excerpt should be bounded")

  claim_section = section_body(report, "## Source-Backed Claims")
  assert_includes(claim_section, "claim_source_backed", "canonical claim should render")
  assert_includes(claim_section, "Reports Stay Auditable", "canonical claim title should render")
  assert_includes(report, "edge_memory_claim", "connected canonical relationship should render")
  assert_absent(report, "edge_dangling", "dangling relationship should not render")
end

def case_trust_boundary_excludes_unreviewed_and_unsupported(tmpdir)
  vault = tmpdir + "boundary-vault"
  output = tmpdir + "boundary.md"
  complete_fixture(vault)

  _stdout, stderr, status = run_report(vault, output)
  assert_success(status, stderr)
  report = output.read

  [
    "Pending Report Leak",
    "Rejected Report Leak",
    "Deprecated Report Leak",
    "Archived Report Leak",
    "Unsupported Report Leak",
    "Malformed Unsupported Report Leak",
    "01_agent_inbox"
  ].each { |text| assert_absent(report, text, "untrusted records should be excluded") }
end

def case_empty_sections_render_empty_state(tmpdir)
  vault = tmpdir + "empty-vault"
  output = tmpdir + "empty.md"

  _stdout, stderr, status = run_report(vault, output)
  assert_success(status, stderr)
  report = output.read
  SECTION_HEADINGS.each do |heading|
    assert_includes(section_body(report, heading), "No reviewed records found.", "#{heading} should render an empty state")
  end
end

def case_duplicate_ids_fail_without_overwriting(tmpdir)
  vault = tmpdir + "duplicate-vault"
  output = tmpdir + "duplicate.md"
  output.write("previous report\n")

  write_record(
    vault + "02_notes/memories/memory_a.md",
    base_frontmatter("duplicate_id", "memory"),
    "# Memory A\n\nFirst.\n"
  )
  write_record(
    vault + "03_canonical_model/claims/claim_a.md",
    base_frontmatter("duplicate_id", "claim"),
    "# Claim A\n\nSecond.\n"
  )

  _stdout, stderr, status = run_report(vault, output)
  assert_failure(status, stderr, "duplicate")
  assert_includes(stderr, "duplicate_id", "duplicate error should name the id")
  assert(output.read == "previous report\n", "duplicate failure should preserve existing output")
end

def case_missing_required_metadata_fails_without_overwriting(tmpdir)
  %w[id type status review_status].each do |field|
    vault = tmpdir + "missing-#{field}-vault"
    output = tmpdir + "missing-#{field}.md"
    output.write("previous report\n")
    frontmatter = base_frontmatter("memory_missing_#{field}", "memory")
    frontmatter.delete(field)
    write_record(
      vault + "02_notes/memories/memory_missing.md",
      frontmatter,
      "# Missing #{field}\n\nThis would otherwise be exportable.\n"
    )

    _stdout, stderr, status = run_report(vault, output)
    assert_failure(status, stderr, field)
    assert(output.read == "previous report\n", "missing #{field} failure should preserve existing output")
  end
end

def case_invalid_report_time_fails_clearly(tmpdir)
  vault = tmpdir + "invalid-time-vault"
  output = tmpdir + "invalid-time.md"

  _stdout, stderr, status = run_report(vault, output, env: { "NOUS_REPORT_TIME" => "not-a-time" })
  assert_failure(status, stderr, "NOUS_REPORT_TIME")
end

def case_fixed_time_runs_are_byte_identical(tmpdir)
  vault = tmpdir + "deterministic-vault"
  first = tmpdir + "first.md"
  second = tmpdir + "second.md"
  complete_fixture(vault)

  _stdout, stderr, status = run_report(vault, first)
  assert_success(status, stderr)
  _stdout, stderr, status = run_report(vault, second)
  assert_success(status, stderr)
  assert(first.read == second.read, "fixed-time report should be byte-identical across runs")
end

def case_default_output_and_path_overrides_are_supported(tmpdir)
  vault = tmpdir + "default-output-vault"
  complete_fixture(vault)

  stdout, stderr, status = run_report(vault)
  assert_success(status, stderr)
  default_output = vault + "04_generated/reports/nous.md"
  assert(default_output.file?, "default output should be vault/04_generated/reports/nous.md")
  assert(stdout.include?("04_generated/reports/nous.md"), "stdout should include the default output path")

  custom_output = tmpdir + "custom/report.md"
  stdout, stderr, status = run_report(vault, custom_output)
  assert_success(status, stderr)
  assert(custom_output.file?, "custom --output path should be written")
  assert(stdout.include?(custom_output.to_s), "stdout should include the custom output path")
end

Dir.mktmpdir("nous-report-test-") do |dir|
  tmpdir = Pathname(dir)
  failures = []
  {
    "complete report renders the accepted contract" => method(:case_complete_report_renders_contract),
    "trust boundary excludes unreviewed and unsupported records" => method(:case_trust_boundary_excludes_unreviewed_and_unsupported),
    "empty sections render explicit empty states" => method(:case_empty_sections_render_empty_state),
    "duplicate IDs fail without overwriting output" => method(:case_duplicate_ids_fail_without_overwriting),
    "missing required metadata fails without overwriting output" => method(:case_missing_required_metadata_fails_without_overwriting),
    "invalid NOUS_REPORT_TIME fails clearly" => method(:case_invalid_report_time_fails_clearly),
    "fixed-time runs are byte-identical" => method(:case_fixed_time_runs_are_byte_identical),
    "default output and path overrides are supported" => method(:case_default_output_and_path_overrides_are_supported)
  }.each do |name, test_case|
    begin
      test_case.call(tmpdir)
      puts "ok - #{name}"
    rescue StandardError => error
      failures << [name, error]
      warn "not ok - #{name}: #{error.message}"
    end
  end

  begin
    assert_no_repo_vault_writes
  rescue StandardError => error
    failures << ["repository vault leak scan", error]
    warn "not ok - repository vault leak scan: #{error.message}"
  end

  unless failures.empty?
    warn "\n#{failures.length} generate_nous_report test(s) failed:"
    failures.each do |name, error|
      warn "- #{name}: #{error.message}"
    end
    exit 1
  end
end

puts "generate_nous_report tests ok"
