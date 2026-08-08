#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "psych"
require "tmpdir"

ROOT = Pathname(__dir__).parent.expand_path
SCRIPT = ROOT + "scripts/ingest_artifact.rb"
REVIEW_SCRIPT = ROOT + "scripts/review_queue.rb"
EXPORT_SCRIPT = ROOT + "scripts/export_graph.rb"
REPORT_SCRIPT = ROOT + "scripts/generate_nous_report.rb"
TEST_DATE = "2026-07-04"
REVIEW_TIME = "2026-07-05T08:30:00Z"
GRAPH_TIME = "2026-07-05T09:00:00Z"
REPORT_TIME = "2026-07-05T09:30:00Z"

def run_ingest(source, vault_root, type:, date: TEST_DATE, context: nil, represented_date: nil, env: {})
  command = ["ruby", SCRIPT.to_s, "--type", type, "--date", date, "--vault-root", vault_root.to_s]
  command.concat(["--context", context]) unless context.nil?
  command.concat(["--represented-date", represented_date]) unless represented_date.nil?
  command << source.to_s unless source.nil?
  Open3.capture3(env, *command)
end

def run_ingest_raw(args, env: {})
  Open3.capture3(env, "ruby", SCRIPT.to_s, *args)
end

def run_review(vault, *args)
  env = { "NOUS_REVIEW_TIME" => REVIEW_TIME }
  command = ["ruby", REVIEW_SCRIPT.to_s, args.first, "--vault-root", vault.to_s, *args.drop(1)]
  Open3.capture3(env, *command)
end

def run_export(vault, output)
  env = { "NOUS_GRAPH_TIME" => GRAPH_TIME }
  command = ["ruby", EXPORT_SCRIPT.to_s, "--vault-root", vault.to_s, "--output", output.to_s]
  Open3.capture3(env, *command)
end

def run_report(vault, output)
  env = { "NOUS_REPORT_TIME" => REPORT_TIME }
  command = ["ruby", REPORT_SCRIPT.to_s, "--vault-root", vault.to_s, "--output", output.to_s]
  Open3.capture3(env, *command)
end

def assert(condition, message)
  raise message unless condition
end

def assert_success(status, stderr)
  assert(status.success?, "expected command to pass: #{stderr}")
end

def assert_failure(status, stderr, expected)
  assert(!status.success?, "expected command to fail")
  assert(stderr.include?(expected), "expected error to include #{expected.inspect}, got #{stderr.inspect}")
  assert(!stderr.include?("scripts/ingest_artifact.rb:"), "failure should not expose a Ruby stack trace: #{stderr.inspect}")
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

def output_path(stdout, key)
  line = stdout.lines.find { |candidate| candidate.start_with?("#{key}: ") }
  raise "missing #{key} output line in #{stdout.inspect}" if line.nil?

  Pathname(line.split(": ", 2).last.strip)
end

def sha256(path)
  Digest::SHA256.file(path.to_s).hexdigest
end

def snapshot(path)
  stat = path.lstat
  {
    bytes: path.binread,
    basename: path.basename.to_s,
    mode: stat.mode & 0o777,
    size: stat.size,
    sha256: sha256(path),
    realpath: path.realpath.to_s
  }
end

def assert_source_unchanged(path, before)
  after = snapshot(path)
  assert(after == before, "source changed: before #{before.inspect}, after #{after.inspect}")
end

def assert_under_vault(path, vault)
  relative = path.realpath.relative_path_from(vault.realpath).to_s
  assert(!relative.start_with?(".."), "#{path} is outside #{vault}")
rescue ArgumentError
  raise "#{path} is outside #{vault}"
end

def raw_directory(type)
  { "writing" => "writing", "image" => "images", "project" => "projects" }.fetch(type)
end

def assert_no_external_path_serialized(vault, source)
  serialized = vault.children.flat_map { |child| child.find.select(&:file?) }.select { |path| path.extname == ".md" }
  external_path = source.expand_path.to_s
  offenders = serialized.select { |path| path.read.include?(external_path) }
  assert(offenders.empty?, "external source path leaked into #{offenders.map(&:to_s).join(", ")}")
end

def assert_no_repo_vault_writes
  repo_vault = ROOT + "vault"
  return unless repo_vault.directory?

  leaked = repo_vault.find.select(&:file?).map(&:to_s).grep(/2026-07-04|m6-|artifact_#{TEST_DATE}/)
  assert(leaked.empty?, "test wrote M6 fixtures into repo vault: #{leaked.inspect}")
end

def assert_common_records(vault, source, stdout, type:, slug:, extension:, context: nil, represented_date: nil, suffix: nil)
  copied = output_path(stdout, "copied_source")
  artifact = output_path(stdout, "artifact")
  draft = output_path(stdout, "draft_note")
  name_suffix = suffix.nil? ? "" : "-#{suffix}"
  raw_dir = raw_directory(type)
  expected_payload = vault + "00_raw_artifacts/#{raw_dir}/files/#{slug}#{name_suffix}#{extension}"
  expected_artifact = vault + "00_raw_artifacts/#{raw_dir}/notes/artifact_#{TEST_DATE}_#{slug}#{name_suffix}.md"
  expected_draft = vault + "01_agent_inbox/notes/note_#{TEST_DATE}_#{slug}#{name_suffix}.md"

  assert(copied == expected_payload, "copied payload path is wrong: #{copied}")
  assert(artifact == expected_artifact, "artifact path is wrong: #{artifact}")
  assert(draft == expected_draft, "draft path is wrong: #{draft}")
  [copied, artifact, draft].each do |path|
    assert(path.file?, "expected #{path} to exist")
    assert_under_vault(path, vault)
  end

  artifact_fm = frontmatter(artifact)
  draft_fm = frontmatter(draft)
  payload_relative = copied.relative_path_from(vault).to_s
  artifact_relative = artifact.relative_path_from(vault).to_s

  assert(copied.binread == source.binread, "copied payload bytes differ from source")
  assert(sha256(copied) == sha256(source), "copied payload digest differs from source")
  assert(artifact_fm["id"] == "artifact_#{TEST_DATE}_#{slug}#{name_suffix}", "artifact id is wrong")
  assert(artifact_fm["type"] == "artifact", "artifact type is wrong")
  assert(artifact_fm["schema_version"] == "0.1", "artifact schema version is wrong")
  assert(artifact_fm["status"] == "draft", "artifact status is wrong")
  assert(artifact_fm["review_status"] == "needs_review", "artifact review status is wrong")
  assert(artifact_fm["created"] == TEST_DATE, "artifact created date is wrong")
  assert(artifact_fm["updated"] == TEST_DATE, "artifact updated date is wrong")
  assert(artifact_fm["source"]["type"] == type, "artifact source type is wrong")
  assert(artifact_fm["source"]["path"] == payload_relative, "artifact source path should be copied payload")
  assert(artifact_fm["source"]["original_filename"] == source.basename.to_s, "original filename is wrong")
  assert(artifact_fm["source"]["sha256"] == sha256(source), "artifact sha256 is wrong")
  assert(artifact_fm["source"]["bytes"] == source.size, "artifact byte count is wrong")
  assert(artifact_fm["source"]["extraction_method"] == "import", "artifact extraction method is wrong")
  assert(artifact_fm["source"]["represented_date"] == represented_date, "represented date is wrong") if represented_date
  assert(artifact_fm["interpretation_level"] == "none", "artifact interpretation level is wrong")
  assert(artifact_fm["tags"] == [], "artifact tags should be empty")

  assert(draft_fm["id"] == "note_#{TEST_DATE}_#{slug}#{name_suffix}", "draft id is wrong")
  assert(draft_fm["type"] == "note", "draft type is wrong")
  assert(draft_fm["review_status"] == "agent_generated", "draft review status is wrong")
  assert(draft_fm["interpretation_level"] == "low", "draft interpretation level is wrong")
  assert(draft_fm["source"]["path"] == artifact_relative, "draft source path should be artifact record")
  assert(draft_fm["evidence"] == [{ "id" => artifact_fm["id"], "path" => artifact_relative }], "draft evidence is wrong")
  assert(draft_fm["counterevidence"] == [], "draft counterevidence should be empty")
  assert(draft_fm["related"] == [], "draft related should be empty")
  assert(draft_fm["tags"] == [], "draft tags should be empty")

  if context
    assert(markdown_section(artifact, "User-Provided Context") == context, "artifact context is not separated")
    assert(markdown_section(draft, "User Context") == context, "draft context is not separated")
  end

  assert_no_external_path_serialized(vault, source)
  { copied: copied, artifact: artifact, draft: draft }
end

def assert_text_import(vault, source, type:, slug:, extension:, expected_facts:)
  before = snapshot(source)
  context = "User says this file captures project intent."
  stdout, stderr, status = run_ingest(
    source,
    vault,
    type: type,
    context: context,
    represented_date: "2026-06-30"
  )
  assert_success(status, stderr)
  paths = assert_common_records(
    vault,
    source,
    stdout,
    type: type,
    slug: slug,
    extension: extension,
    context: context,
    represented_date: "2026-06-30"
  )

  observed = markdown_section(paths[:artifact], "Observed Content")
  assert(observed.include?(expected_facts.first.sub(/\A- /, "")), "artifact should preserve source excerpt")
  facts = markdown_section(paths[:draft], "Source-Backed Facts").lines.map(&:strip).reject(&:empty?)
  assert(facts.length <= 3, "draft should include at most three facts")
  assert(facts == expected_facts, "draft facts should be extractive and bounded")
  assert(markdown_section(paths[:draft], "Tentative Hypotheses").empty?, "draft should not add hypotheses")
  assert_source_unchanged(source, before)
  paths
end

def assert_binary_import(vault, source, type:, slug:, extension:)
  before = snapshot(source)
  stdout, stderr, status = run_ingest(source, vault, type: type)
  assert_success(status, stderr)
  paths = assert_common_records(vault, source, stdout, type: type, slug: slug, extension: extension)
  assert(markdown_section(paths[:artifact], "Observed Content").empty?, "binary artifact should not claim observed content")
  assert(markdown_section(paths[:draft], "Source-Backed Facts").include?("Imported #{type} artifact"), "binary draft should be metadata-only")
  assert(markdown_section(paths[:draft], "Tentative Hypotheses").empty?, "binary draft should not add hypotheses")
  markdown = paths[:artifact].read + paths[:draft].read
  forbidden = ["person", "face", "emotion", "mood", "looks like", "shows", "visible", "theme"]
  forbidden.each { |word| assert(!markdown.downcase.include?(word), "binary/image note should not infer #{word.inspect}") }
  assert_source_unchanged(source, before)
  paths
end

def assert_rejected_source(tmpdir, source, type, expected)
  before = source.file? && !source.symlink? ? snapshot(source) : nil
  vault = tmpdir + "reject-#{source.basename.to_s.gsub(/[^a-z0-9]+/i, "-")}-vault"
  _stdout, stderr, status = run_ingest(source, vault, type: type)
  assert_failure(status, stderr, expected)
  assert_source_unchanged(source, before) if before
  assert(!vault.exist? || vault.find.select(&:file?).empty?, "failed import should not create final files for #{source}")
end

Dir.mktmpdir("nous-ingest-artifact-test-") do |dir|
  tmpdir = Pathname(dir)

  writing = tmpdir + "M6 Journal.md"
  writing.write("# M6 Fixture\n\nLine one preserves source wording.\nLine two stays extractive.\nLine three is enough.\nLine four is ignored.")
  assert_text_import(
    tmpdir + "writing-vault",
    writing,
    type: "writing",
    slug: "m6-journal",
    extension: ".md",
    expected_facts: [
      "- # M6 Fixture",
      "- Line one preserves source wording.",
      "- Line two stays extractive."
    ]
  )

  long_writing = tmpdir + "Long Writing.md"
  long_writing.write("A" * 2_100 + "TAIL_MUST_NOT_BE_EMBEDDED")
  long_stdout, long_stderr, long_status = run_ingest(long_writing, tmpdir + "long-writing-vault", type: "writing")
  assert_success(long_status, long_stderr)
  long_artifact = output_path(long_stdout, "artifact")
  assert(markdown_section(long_artifact, "Observed Content").length == 2_000, "observed excerpt should be bounded")
  assert(!long_artifact.read.include?("TAIL_MUST_NOT_BE_EMBEDDED"), "artifact note should not embed text beyond the bounded excerpt")

  image = tmpdir + "Photo.PNG"
  image.binwrite("\x89PNG\r\n\x1A\nm6-image-bytes\x00\xFF".b)
  assert_binary_import(tmpdir + "image-vault", image, type: "image", slug: "photo", extension: ".PNG")

  project_text = tmpdir + "Project Plan.JSON"
  project_text.write("{\n  \"title\": \"M6 Fixture\",\n  \"next\": \"Keep facts extractive\"\n}\n")
  paths = assert_text_import(
    tmpdir + "project-text-vault",
    project_text,
    type: "project",
    slug: "project-plan",
    extension: ".JSON",
    expected_facts: [
      "- {",
      "- \"title\": \"M6 Fixture\",",
      "- \"next\": \"Keep facts extractive\""
    ]
  )
  external_copy = paths[:copied].read
  FileUtils.rm_f(project_text)
  assert(paths[:copied].read == external_copy, "copied payload should remain after external source removal")
  assert((paths[:copied].dirname.parent + "notes/#{paths[:artifact].basename}").file?, "artifact remains internally resolvable")
  assert((paths[:draft].dirname.parent.parent + frontmatter(paths[:draft])["evidence"].first["path"]).file?, "evidence path should resolve")

  project_binary = tmpdir + "Prototype.webp"
  project_binary.binwrite("RIFF\x10\x00\x00\x00WEBPm6".b)
  assert_binary_import(tmpdir + "project-binary-vault", project_binary, type: "project", slug: "prototype", extension: ".webp")

  duplicate = tmpdir + "Duplicate.txt"
  duplicate.write("Duplicate import source.")
  vault = tmpdir + "duplicate-vault"
  first_stdout, first_stderr, first_status = run_ingest(duplicate, vault, type: "writing")
  second_stdout, second_stderr, second_status = run_ingest(duplicate, vault, type: "writing")
  assert_success(first_status, first_stderr)
  assert_success(second_status, second_stderr)
  assert_common_records(vault, duplicate, first_stdout, type: "writing", slug: "duplicate", extension: ".txt")
  assert_common_records(vault, duplicate, second_stdout, type: "writing", slug: "duplicate", extension: ".txt", suffix: 2)

  env_source = tmpdir + "Env Date.txt"
  env_source.write("Environment date should be used.")
  env_vault = tmpdir + "env-date-vault"
  stdout, stderr, status = run_ingest_raw(
    ["--type", "writing", "--vault-root", env_vault.to_s, env_source.to_s],
    env: { "NOUS_INGEST_DATE" => "2026-07-03" }
  )
  assert_success(status, stderr)
  assert(stdout.include?("artifact_2026-07-03_env-date.md"), "NOUS_INGEST_DATE should set deterministic IDs")
  stdout, stderr, status = run_ingest_raw(
    ["--type", "writing", "--date", "2026-07-02", "--vault-root", env_vault.to_s, env_source.to_s],
    env: { "NOUS_INGEST_DATE" => "2026-07-03" }
  )
  assert_success(status, stderr)
  assert(stdout.include?("artifact_2026-07-02_env-date-2.md"), "--date should override NOUS_INGEST_DATE and preserve shared suffix collisions")

  missing = tmpdir + "missing.md"
  _stdout, stderr, status = run_ingest(missing, tmpdir + "missing-vault", type: "writing")
  assert_failure(status, stderr, "source path does not exist")

  directory = tmpdir + "directory.md"
  directory.mkdir
  assert_rejected_source(tmpdir, directory, "writing", "source path is a directory")

  hidden = tmpdir + ".hidden.md"
  hidden.write("hidden")
  assert_rejected_source(tmpdir, hidden, "writing", "hidden files are not supported")

  extensionless = tmpdir + "extensionless"
  extensionless.write("extensionless")
  assert_rejected_source(tmpdir, extensionless, "writing", "unsupported source extension")

  unsupported = tmpdir + "paper.pdf"
  unsupported.write("pdf")
  assert_rejected_source(tmpdir, unsupported, "writing", "unsupported source extension")

  mismatch = tmpdir + "photo.jpg"
  mismatch.binwrite("jpeg")
  assert_rejected_source(tmpdir, mismatch, "writing", "unsupported source extension")

  invalid_utf8 = tmpdir + "invalid.md"
  invalid_utf8.binwrite("\xFF".b)
  assert_rejected_source(tmpdir, invalid_utf8, "writing", "source file must be valid UTF-8")

  symlink_target = tmpdir + "target.md"
  symlink_target.write("target")
  symlink = tmpdir + "link.md"
  File.symlink(symlink_target, symlink)
  assert_rejected_source(tmpdir, symlink, "writing", "symlinks are not supported")

  _stdout, stderr, status = run_ingest_raw(["--date", TEST_DATE, writing.to_s])
  assert_failure(status, stderr, "type is required")
  _stdout, stderr, status = run_ingest_raw(["--type", "audio", "--date", TEST_DATE, writing.to_s])
  assert_failure(status, stderr, "unsupported type")
  _stdout, stderr, status = run_ingest_raw(["--type", "writing", "--date", "07/04/2026", writing.to_s])
  assert_failure(status, stderr, "date must use YYYY-MM-DD")
  _stdout, stderr, status = run_ingest_raw(["--type", "writing", "--date", TEST_DATE])
  assert_failure(status, stderr, "expected exactly one source path")

  rollback_source = tmpdir + "Rollback.txt"
  rollback_source.write("Rollback should remove staged outputs.")
  rollback_vault = tmpdir + "rollback-vault"
  (rollback_vault + "01_agent_inbox/notes").mkpath
  FileUtils.chmod(0o500, rollback_vault + "01_agent_inbox/notes")
  begin
    _stdout, stderr, status = run_ingest(rollback_source, rollback_vault, type: "writing")
    assert_failure(status, stderr, "failed to finalize import")
  ensure
    FileUtils.chmod(0o700, rollback_vault + "01_agent_inbox/notes")
  end
  created_after_failure = rollback_vault.find.select(&:file?).reject { |path| path.basename.to_s == "AGENT.md" }
  assert(created_after_failure.empty?, "rollback failure left files: #{created_after_failure.inspect}")
  assert(rollback_source.read == "Rollback should remove staged outputs.", "rollback changed source")

  review_source = tmpdir + "Review Project.md"
  review_source.write("# Review Project\n\nA project note can be reviewed.\n")
  review_vault = tmpdir + "review-vault"
  stdout, stderr, status = run_ingest(review_source, review_vault, type: "project")
  assert_success(status, stderr)
  review_paths = assert_common_records(review_vault, review_source, stdout, type: "project", slug: "review-project", extension: ".md")
  payload_hash = sha256(review_paths[:copied])
  artifact_hash = sha256(review_paths[:artifact])

  stdout, stderr, status = run_review(review_vault, "list")
  assert_success(status, stderr)
  assert(stdout.include?(review_paths[:draft].relative_path_from(review_vault).to_s), "review list should include M6 draft")
  assert(stdout.include?(review_paths[:artifact].relative_path_from(review_vault).to_s), "review list should include artifact evidence")

  stdout, stderr, status = run_review(review_vault, "show", review_paths[:draft].to_s)
  assert_success(status, stderr)
  assert(stdout.include?("Path: #{review_paths[:draft].relative_path_from(review_vault)}"), "review show path is wrong")
  assert(stdout.include?("- #{review_paths[:artifact].relative_path_from(review_vault)}"), "review show evidence is wrong")

  graph_output = tmpdir + "raw-m6-graph.json"
  stdout, stderr, status = run_export(review_vault, graph_output)
  assert_success(status, stderr)
  graph = JSON.parse(graph_output.read)
  assert(graph["nodes"].empty?, "raw M6 imports should not enter graph nodes")
  assert(graph["edges"].empty?, "raw M6 imports should not enter graph edges")
  assert(!graph_output.read.include?("review-project"), "raw M6 artifact should not leak into graph output")

  report_output = tmpdir + "raw-m6-report.md"
  stdout, stderr, status = run_report(review_vault, report_output)
  assert_success(status, stderr)
  assert(!report_output.read.include?("Review Project"), "raw M6 artifact should not leak into report output")
  assert(!report_output.read.include?("01_agent_inbox"), "raw M6 inbox note should not leak into report output")

  stdout, stderr, status = run_review(review_vault, "approve", "--as", "project", review_paths[:draft].to_s)
  assert_success(status, stderr)
  approved = review_vault + "02_notes/projects/#{review_paths[:draft].basename}"
  assert(approved.file?, "approved project note is missing")
  assert(frontmatter(approved)["type"] == "project", "approved note type is wrong")
  assert(frontmatter(approved)["evidence"].first["path"] == review_paths[:artifact].relative_path_from(review_vault).to_s, "approved note lost evidence")
  assert(sha256(review_paths[:copied]) == payload_hash, "approval mutated copied payload")
  assert(sha256(review_paths[:artifact]) == artifact_hash, "approval mutated artifact record")

  assert_no_repo_vault_writes
end

puts "ingest_artifact tests ok"
