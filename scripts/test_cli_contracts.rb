#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "fileutils"
require "pathname"
require "psych"
require "tmpdir"

ROOT = Pathname(__dir__).parent.expand_path
SCRIPTS = {
  ingest_text: ROOT + "scripts/ingest_text.rb",
  ingest_artifact: ROOT + "scripts/ingest_artifact.rb",
  review_queue: ROOT + "scripts/review_queue.rb",
  export_graph: ROOT + "scripts/export_graph.rb",
  generate_nous_report: ROOT + "scripts/generate_nous_report.rb"
}.freeze

TEXT_DATE = "2026-02-03"
ENV_DATE = "2026-01-01"
REVIEW_TIME = "2026-02-04T05:06:07Z"
GRAPH_TIME = "2026-02-05T06:07:08Z"
REPORT_TIME = "2026-02-06T07:08:09Z"
SYNTHETIC_TEXT = <<~TEXT
  Synthetic M7 baseline fixture.
  I turn uncertainty into small systems.
  This text is not personal data.
TEXT
LEAK_MARKERS = [
  "Synthetic M7 baseline fixture",
  "m7-cli-contract",
  "note_cli_contract",
  "claim_cli_contract",
  "edge_cli_contract",
  "CLI Contract Memory"
].freeze

def assert(condition, message)
  raise message unless condition
end

def run_script(name, args, env: {}, chdir: ROOT)
  Open3.capture3(env, "ruby", SCRIPTS.fetch(name).to_s, *args, chdir: chdir.to_s)
end

def assert_success(status, stderr)
  assert(status.success?, "expected command to pass: #{stderr}")
end

def assert_failure(status, stderr, prefix, expected)
  assert(!status.success?, "expected command to fail")
  assert(stderr.start_with?("#{prefix}: "), "expected stderr prefix #{prefix.inspect}, got #{stderr.inspect}")
  assert(stderr.include?(expected), "expected stderr to include #{expected.inspect}, got #{stderr.inspect}")
  assert_no_stack_trace(stderr)
end

def assert_no_stack_trace(stderr)
  assert(!stderr.match?(/\.rb:\d+:in /), "failure should not expose Ruby stack trace: #{stderr.inspect}")
  assert(!stderr.include?("\n\tfrom "), "failure should not expose Ruby stack trace: #{stderr.inspect}")
end

def assert_stdout_lines(stdout, prefixes)
  lines = stdout.lines.map(&:chomp)
  assert(lines.length == prefixes.length, "expected #{prefixes.length} stdout lines, got #{lines.inspect}")
  prefixes.zip(lines).each do |prefix, line|
    assert(line.start_with?("#{prefix}: "), "expected stdout line prefix #{prefix.inspect}, got #{line.inspect}")
  end
end

def output_path(stdout, key)
  line = stdout.lines.find { |candidate| candidate.start_with?("#{key}: ") }
  raise "missing #{key} output line in #{stdout.inspect}" if line.nil?

  Pathname(line.split(": ", 2).last.strip)
end

def frontmatter(path)
  text = path.read
  match = text.match(/\A---\n(.*?)\n---\n/m)
  raise "missing frontmatter in #{path}" unless match

  Psych.safe_load(match[1], aliases: false)
end

def yaml_frontmatter(data)
  Psych.dump(data).sub(/\A---\n/, "")
end

def write_note(path, frontmatter, body = "# Fixture\n\nSynthetic review item.\n")
  path.dirname.mkpath
  path.write("---\n#{yaml_frontmatter(frontmatter)}---\n\n#{body}")
end

def base_frontmatter(id, type, extra = {})
  {
    "id" => id,
    "type" => type,
    "schema_version" => "0.1",
    "status" => "draft",
    "review_status" => "agent_generated",
    "confidence" => 0.7,
    "created" => "2026-02-01",
    "updated" => "2026-02-01",
    "source" => { "type" => "text", "path" => "00_raw_artifacts/text/artifact_cli_contract.md", "extraction_method" => "archivist_agent" },
    "evidence" => [{ "id" => "artifact_cli_contract", "path" => "00_raw_artifacts/text/artifact_cli_contract.md" }],
    "counterevidence" => [],
    "tags" => []
  }.merge(extra)
end

def reviewed_memory(path)
  write_note(
    path,
    base_frontmatter(
      "memory_cli_contract",
      "memory",
      "status" => "active",
      "review_status" => "reviewed"
    ),
    "# CLI Contract Memory\n\nA reviewed target for merge characterization.\n"
  )
end

def review_fixture(vault, name, kind)
  directory = {
    "note" => "01_agent_inbox/notes",
    "claim" => "01_agent_inbox/claims",
    "relationship" => "01_agent_inbox/relationships"
  }.fetch(kind)
  path = vault + "#{directory}/#{name}.md"
  frontmatter = base_frontmatter(name, kind)
  if kind == "relationship"
    frontmatter["relationship"] = { "from" => "note_cli_contract", "to" => "claim_cli_contract", "type" => "supports" }
  end
  write_note(path, frontmatter)
  path
end

def assert_no_repo_vault_writes
  repo_vault = ROOT + "vault"
  return unless repo_vault.directory?

  offenders = repo_vault.find.select(&:file?).select do |path|
    text = path.binread
    LEAK_MARKERS.any? { |marker| path.to_s.include?(marker) || text.include?(marker) }
  end
  assert(offenders.empty?, "CLI contract fixtures leaked into repo vault: #{offenders.map(&:to_s).inspect}")
end

def case_help_contracts(tmpdir)
  {
    ingest_text: ["--help", "Usage: ruby scripts/ingest_text.rb [options] SOURCE_PATH"],
    ingest_artifact: ["--help", "Usage: ruby scripts/ingest_artifact.rb --type writing|image|project [options] SOURCE_PATH"],
    review_queue: ["list", "--help", "Usage: ruby scripts/review_queue.rb list [--sort priority|created|confidence] [--vault-root PATH]"],
    export_graph: ["--help", "Usage: ruby scripts/export_graph.rb [--vault-root PATH] [--output PATH]"],
    generate_nous_report: ["--help", "Usage: ruby scripts/generate_nous_report.rb [--vault-root PATH] [--output PATH]"]
  }.each do |name, values|
    expected_usage = values.pop
    stdout, stderr, status = run_script(name, values, chdir: tmpdir)
    assert_success(status, stderr)
    assert(stdout.start_with?(expected_usage), "#{name} help usage changed: #{stdout.inspect}")
    assert(stderr.empty?, "#{name} help should not write stderr: #{stderr.inspect}")
  end
  assert(tmpdir.children.empty?, "help commands should not create files: #{tmpdir.children.inspect}")
end

def case_failure_contracts(tmpdir)
  source = tmpdir + "source.txt"
  source.write(SYNTHETIC_TEXT)

  [
    [:ingest_text, ["--unknown"], "ingest_text", "invalid option"],
    [:ingest_artifact, ["--unknown"], "ingest_artifact", "invalid option"],
    [:review_queue, ["list", "--unknown"], "review_queue", "invalid option"],
    [:export_graph, ["--unknown"], "export_graph", "invalid option"],
    [:generate_nous_report, ["--unknown"], "generate_nous_report", "invalid option"],
    [:ingest_text, ["--date", TEXT_DATE], "ingest_text", "expected exactly one source path"],
    [:ingest_text, ["--date", TEXT_DATE, source.to_s, source.to_s], "ingest_text", "expected exactly one source path"],
    [:ingest_artifact, ["--type", "writing", "--date", TEXT_DATE], "ingest_artifact", "expected exactly one source path"],
    [:review_queue, ["show", "--vault-root", (tmpdir + "vault").to_s], "review_queue", "show expects 1 path argument"],
    [:review_queue, ["show", "--vault-root", (tmpdir + "vault").to_s, "a.md", "b.md"], "review_queue", "show expects 1 path argument"],
    [:export_graph, ["extra"], "export_graph", "unexpected arguments: extra"],
    [:generate_nous_report, ["extra"], "generate_nous_report", "unexpected arguments: extra"]
  ].each do |name, args, prefix, expected|
    _stdout, stderr, status = run_script(name, args, chdir: tmpdir)
    assert_failure(status, stderr, prefix, expected)
  end
end

def case_ingestion_success_contracts(tmpdir)
  source = tmpdir + "m7-cli-contract.txt"
  source.write(SYNTHETIC_TEXT)

  text_vault = tmpdir + "text-vault"
  stdout, stderr, status = run_script(
    :ingest_text,
    ["--date", TEXT_DATE, "--vault-root", text_vault.to_s, source.to_s],
    env: { "NOUS_INGEST_DATE" => ENV_DATE },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["artifact", "draft_note"])
  artifact = output_path(stdout, "artifact")
  draft = output_path(stdout, "draft_note")
  assert(artifact == text_vault + "00_raw_artifacts/text/artifact_#{TEXT_DATE}_m7-cli-contract.md", "ingest_text artifact path changed")
  assert(draft == text_vault + "01_agent_inbox/notes/note_#{TEXT_DATE}_m7-cli-contract.md", "ingest_text draft path changed")
  assert(frontmatter(artifact)["created"] == TEXT_DATE, "--date should beat NOUS_INGEST_DATE")
  assert(!artifact.read.include?(ENV_DATE), "environment date should not leak when --date is explicit")

  artifact_vault = tmpdir + "artifact-vault"
  stdout, stderr, status = run_script(
    :ingest_artifact,
    ["--type", "writing", "--date", TEXT_DATE, "--vault-root", artifact_vault.to_s, source.to_s],
    env: { "NOUS_INGEST_DATE" => ENV_DATE },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["copied_source", "artifact", "draft_note"])
  assert(frontmatter(output_path(stdout, "artifact"))["created"] == TEXT_DATE, "ingest_artifact --date should beat NOUS_INGEST_DATE")
end

def case_ingestion_default_root_contracts(tmpdir)
  clone_root = tmpdir + "default-root-clone"
  clone_scripts = clone_root + "scripts"
  clone_vault = clone_root + "vault"
  clone_lib = clone_root + "lib"
  cloned_scripts = {
    ingest_text: clone_scripts + "ingest_text.rb",
    ingest_artifact: clone_scripts + "ingest_artifact.rb"
  }
  clone_scripts.mkpath
  FileUtils.cp_r(ROOT + "lib", clone_lib)
  cloned_scripts.each do |name, target|
    FileUtils.cp(SCRIPTS.fetch(name), target)
  end
  run_cloned_script = lambda do |name, args|
    Open3.capture3("ruby", cloned_scripts.fetch(name).to_s, *args, chdir: clone_root.to_s)
  end

  source = tmpdir + "default-root.txt"
  source.write(SYNTHETIC_TEXT)
  artifact_source = tmpdir + "default-artifact-root.txt"
  artifact_source.write(SYNTHETIC_TEXT)

  stdout, stderr, status = run_cloned_script.call(
    :ingest_text,
    ["--date", TEXT_DATE, source.to_s]
  )
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["artifact", "draft_note"])
  text_artifact = output_path(stdout, "artifact")
  assert(
    text_artifact.realpath.relative_path_from(clone_vault.realpath).to_s ==
      "00_raw_artifacts/text/artifact_#{TEXT_DATE}_default-root.md",
    "ingest_text default vault root changed: #{text_artifact}"
  )

  stdout, stderr, status = run_cloned_script.call(
    :ingest_artifact,
    ["--type", "writing", "--date", TEXT_DATE, artifact_source.to_s]
  )
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["copied_source", "artifact", "draft_note"])
  writing_artifact = output_path(stdout, "artifact")
  assert(
    writing_artifact.realpath.relative_path_from(clone_vault.realpath).to_s ==
      "00_raw_artifacts/writing/notes/artifact_#{TEXT_DATE}_default-artifact-root.md",
    "ingest_artifact default vault root changed: #{writing_artifact}"
  )
end

def case_review_success_contracts(tmpdir)
  vault = tmpdir + "review-vault"

  note = review_fixture(vault, "note_cli_contract", "note")
  stdout, stderr, status = run_script(
    :review_queue,
    ["approve", "--vault-root", vault.to_s, "--as", "memory", note.to_s],
    env: { "NOUS_REVIEW_TIME" => REVIEW_TIME },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["approved"])

  claim = review_fixture(vault, "claim_cli_contract", "claim")
  stdout, stderr, status = run_script(
    :review_queue,
    ["reject", "--vault-root", vault.to_s, claim.to_s],
    env: { "NOUS_REVIEW_TIME" => REVIEW_TIME },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["rejected"])

  relationship = review_fixture(vault, "edge_cli_contract", "relationship")
  stdout, stderr, status = run_script(
    :review_queue,
    ["deprecate", "--vault-root", vault.to_s, relationship.to_s],
    env: { "NOUS_REVIEW_TIME" => REVIEW_TIME },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["deprecated"])

  merge_source = review_fixture(vault, "note_cli_contract_merge", "note")
  merge_target = vault + "02_notes/memories/memory_cli_contract.md"
  reviewed_memory(merge_target)
  stdout, stderr, status = run_script(
    :review_queue,
    ["merge", "--vault-root", vault.to_s, "--into", merge_target.to_s, merge_source.to_s],
    env: { "NOUS_REVIEW_TIME" => REVIEW_TIME },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["merged"])

  stdout, stderr, status = run_script(
    :review_queue,
    ["report", "--vault-root", vault.to_s],
    env: { "NOUS_REVIEW_TIME" => REVIEW_TIME },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["report"])
  assert((vault + "04_generated/reports/review_queue.md").file?, "review report default output changed")
end

def case_graph_and_report_output_contracts(tmpdir)
  vault = tmpdir + "output-vault"

  stdout, stderr, status = run_script(:export_graph, ["--vault-root", vault.to_s], env: { "NOUS_GRAPH_TIME" => GRAPH_TIME }, chdir: tmpdir)
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["graph"])
  assert(output_path(stdout, "graph") == Pathname("04_generated/graph/nous_graph.json"), "graph default stdout path should be vault-relative")
  assert((vault + "04_generated/graph/nous_graph.json").file?, "graph default output path changed")

  existing_dir = tmpdir + "existing"
  existing_dir.mkpath
  stdout, stderr, status = run_script(
    :export_graph,
    ["--vault-root", vault.to_s, "--output", "existing/graph.json"],
    env: { "NOUS_GRAPH_TIME" => GRAPH_TIME },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  graph_existing_output = output_path(stdout, "graph")
  assert(graph_existing_output.absolute?, "graph relative output with existing cwd directory should print an absolute cwd path")
  assert(graph_existing_output.realpath == (existing_dir + "graph.json").realpath, "graph relative output with existing cwd directory should resolve from cwd")

  stdout, stderr, status = run_script(
    :export_graph,
    ["--vault-root", vault.to_s, "--output", "missing/graph.json"],
    env: { "NOUS_GRAPH_TIME" => GRAPH_TIME },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  assert(output_path(stdout, "graph") == Pathname("missing/graph.json"), "graph relative output without cwd directory should resolve under vault")
  assert((vault + "missing/graph.json").file?, "graph vault-relative custom output was not written")

  stdout, stderr, status = run_script(:generate_nous_report, ["--vault-root", vault.to_s], env: { "NOUS_REPORT_TIME" => REPORT_TIME }, chdir: tmpdir)
  assert_success(status, stderr)
  assert_stdout_lines(stdout, ["report"])
  assert(output_path(stdout, "report") == Pathname("04_generated/reports/nous.md"), "report default stdout path should be vault-relative")
  assert((vault + "04_generated/reports/nous.md").file?, "report default output path changed")

  stdout, stderr, status = run_script(
    :generate_nous_report,
    ["--vault-root", vault.to_s, "--output", "existing/report.md"],
    env: { "NOUS_REPORT_TIME" => REPORT_TIME },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  report_existing_output = output_path(stdout, "report")
  assert(report_existing_output.absolute?, "report relative output with existing cwd directory should print an absolute cwd path")
  assert(report_existing_output.realpath == (existing_dir + "report.md").realpath, "report relative output with existing cwd directory should resolve from cwd")

  stdout, stderr, status = run_script(
    :generate_nous_report,
    ["--vault-root", vault.to_s, "--output", "missing/report.md"],
    env: { "NOUS_REPORT_TIME" => REPORT_TIME },
    chdir: tmpdir
  )
  assert_success(status, stderr)
  assert(output_path(stdout, "report") == Pathname("missing/report.md"), "report relative output without cwd directory should resolve under vault")
  assert((vault + "missing/report.md").file?, "report vault-relative custom output was not written")
end

Dir.mktmpdir("nous-cli-contract-test-") do |dir|
  tmpdir = Pathname(dir)
  failures = []
  {
    "help contracts" => method(:case_help_contracts),
    "failure prefixes and positional contracts" => method(:case_failure_contracts),
    "ingestion success and date precedence" => method(:case_ingestion_success_contracts),
    "ingestion default vault roots" => method(:case_ingestion_default_root_contracts),
    "review success stdout prefixes" => method(:case_review_success_contracts),
    "graph/report output path semantics" => method(:case_graph_and_report_output_contracts)
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
    warn "\n#{failures.length} CLI contract test(s) failed:"
    failures.each do |name, error|
      warn "- #{name}: #{error.message}"
    end
    exit 1
  end
end

puts "cli contract tests ok"
