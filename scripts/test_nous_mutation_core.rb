#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "fileutils"
require "pathname"
require "psych"
require "tmpdir"

ROOT = Pathname(__dir__).parent.expand_path
LIB = ROOT + "lib"

$LOAD_PATH.unshift(LIB.to_s)
require "nous"

def assert(condition, message)
  raise message unless condition
end

def assert_error(code, message)
  yield
  raise "#{message}: expected #{code}"
rescue Nous::Error => error
  raise "#{message}: expected #{code}, got #{error.code}" unless error.code == code

  error
end

def write_file(path, bytes)
  path.dirname.mkpath
  path.binwrite(bytes)
end

def yaml_frontmatter(data)
  Psych.dump(data).sub(/\A---\n/, "")
end

def write_note(path, frontmatter, body = "# Test\n\nBody.\n")
  path.dirname.mkpath
  path.write("---\n#{yaml_frontmatter(frontmatter)}---\n\n#{body}")
end

def assert_no_temps(vault)
  leftovers = vault.find.select { |path| path.basename.to_s.start_with?(".tmp-nous-") }
  assert(leftovers.empty?, "temporary files should be cleaned up: #{leftovers.map(&:to_s).join(", ")}")
end

def ruby_child(code, args = [], env = {})
  Open3.popen3(env.merge("RUBYLIB" => LIB.to_s), "ruby", "-e", code, *args.map(&:to_s))
end

def frontmatter(path)
  match = path.read.match(/\A---\n(.*?)\n---\n/m)
  raise "missing frontmatter in #{path}" unless match

  Psych.safe_load(match[1], aliases: false)
end

def markdown_section(path, heading)
  match = path.read.match(/^## #{Regexp.escape(heading)}\n\n(.*?)(?=^## |\z)/m)
  raise "missing section #{heading} in #{path}" unless match

  match[1].strip
end

def test_path_guard(tmpdir)
  vault = tmpdir + "vault"
  outside = tmpdir + "outside"
  vault.mkpath
  outside.mkpath
  write_file(vault + "01_agent_inbox/notes/item.md", "ok")
  write_file(outside + "secret.md", "private")

  path = Nous::PathGuard.internal_path(vault_root: vault, path: "01_agent_inbox/../01_agent_inbox/notes/item.md")
  assert(path == (vault + "01_agent_inbox/notes/item.md").realpath, "internal path should normalize")
  assert(
    Nous::PathGuard.relative_path(vault_root: vault, path: path) == "01_agent_inbox/notes/item.md",
    "internal path should convert to vault-relative form"
  )

  assert_error("NOUS_PATH_OUTSIDE_VAULT", "parent traversal should be rejected") do
    Nous::PathGuard.internal_path(vault_root: vault, path: "../outside/secret.md")
  end
  assert_error("NOUS_PATH_OUTSIDE_VAULT", "absolute outside path should be rejected") do
    Nous::PathGuard.internal_path(vault_root: vault, path: outside + "secret.md")
  end

  evil = tmpdir + "vault-evil"
  evil.mkpath
  write_file(evil + "item.md", "evil")
  assert_error("NOUS_PATH_OUTSIDE_VAULT", "sibling prefix collision should be rejected") do
    Nous::PathGuard.internal_path(vault_root: vault, path: evil + "item.md")
  end

  File.symlink((outside + "secret.md").to_s, (vault + "file-link.md").to_s)
  assert_error("NOUS_SYMLINK_REJECTED", "symlinked file escape should be rejected") do
    Nous::PathGuard.internal_path(vault_root: vault, path: "file-link.md")
  end

  File.symlink(outside.to_s, (vault + "dir-link").to_s)
  assert_error("NOUS_SYMLINK_REJECTED", "symlinked directory escape should be rejected") do
    Nous::PathGuard.internal_path(vault_root: vault, path: "dir-link/secret.md")
  end

  File.symlink((vault + "dir-link").to_s, (vault + "chain-link").to_s)
  assert_error("NOUS_SYMLINK_REJECTED", "symlink chain escape should be rejected") do
    Nous::PathGuard.internal_path(vault_root: vault, path: "chain-link/secret.md")
  end

  assert_error("NOUS_RECORD_NOT_FOUND", "missing parent should be rejected unless creation is allowed") do
    Nous::PathGuard.internal_path(vault_root: vault, path: "01_agent_inbox/missing/item.md", allow_missing: true)
  end
  creatable = Nous::PathGuard.internal_path(
    vault_root: vault,
    path: "01_agent_inbox/missing/item.md",
    allow_missing: true,
    create_parent: true
  )
  resolved_vault = Nous::PathGuard.validate_vault_root(vault)
  assert(creatable == (resolved_vault + "01_agent_inbox/missing/item.md").expand_path, "server-controlled missing parent should resolve")

  assert(Nous::PathGuard.operator_source(outside + "secret.md").file?, "external operator source should be accepted")
  File.symlink((outside + "secret.md").to_s, (outside + "source-link.md").to_s)
  assert_error("NOUS_SYMLINK_REJECTED", "external operator source symlink should be rejected") do
    Nous::PathGuard.operator_source(outside + "source-link.md")
  end

  error = assert_error("NOUS_PATH_OUTSIDE_VAULT", "path errors should be sanitized") do
    Nous::PathGuard.internal_path(vault_root: vault, path: outside + "secret.md")
  end
  assert(!error.message.include?(outside.to_s), "path error should not include external absolute path")
end

def test_vault_lock(tmpdir)
  vault = tmpdir + "lock-vault"
  vault.mkpath
  lock = Nous::VaultLock.new(vault_root: vault, timeout: 0.5)
  lock.with_exclusive { assert(true, "exclusive lock should acquire") }
  assert((vault + ".nous.lock").file?, "lock file should exist")
  assert(((vault + ".nous.lock").stat.mode & 0o777) == 0o600, "lock file should use restrictive permissions")

  lock.with_shared do
    shared_code = <<~RUBY
      require "nous"
      Nous::VaultLock.new(vault_root: ARGV.fetch(0), timeout: 0.5).with_shared do
        STDOUT.puts "shared"
      end
    RUBY
    stdout, stderr, status = Open3.capture3({ "RUBYLIB" => LIB.to_s }, "ruby", "-e", shared_code, vault.to_s)
    assert(status.success?, "shared child should acquire alongside shared holder: #{stderr}")
    assert(stdout.strip == "shared", "shared child should report acquisition")

    exclusive_code = <<~RUBY
      require "nous"
      begin
        Nous::VaultLock.new(vault_root: ARGV.fetch(0), timeout: 0.2).with_exclusive {}
      rescue Nous::Error => error
        STDOUT.puts error.code
      end
    RUBY
    stdout, stderr, status = Open3.capture3({ "RUBYLIB" => LIB.to_s }, "ruby", "-e", exclusive_code, vault.to_s)
    assert(status.success?, "exclusive child timeout probe should exit cleanly: #{stderr}")
    assert(stdout.strip == "NOUS_LOCK_TIMEOUT", "exclusive lock should timeout behind shared holder")
  end

  lock.with_exclusive do
    exclusive_code = <<~RUBY
      require "nous"
      begin
        Nous::VaultLock.new(vault_root: ARGV.fetch(0), timeout: 0.2).with_exclusive {}
      rescue Nous::Error => error
        STDOUT.puts error.code
      end
    RUBY
    stdout, stderr, status = Open3.capture3({ "RUBYLIB" => LIB.to_s }, "ruby", "-e", exclusive_code, vault.to_s)
    assert(status.success?, "second exclusive child probe should exit cleanly: #{stderr}")
    assert(stdout.strip == "NOUS_LOCK_TIMEOUT", "second exclusive lock should timeout")
    assert_error("NOUS_INVALID_INPUT", "nested lock acquisition should fail fast") do
      lock.with_shared { raise "should not acquire" }
    end
  end

  begin
    lock.with_exclusive { raise "boom" }
  rescue RuntimeError
    nil
  end
  lock.with_exclusive { assert(true, "lock should release after exceptions") }

  holder_code = <<~RUBY
    require "nous"
    lock = Nous::VaultLock.new(vault_root: ARGV.fetch(0), timeout: 1)
    lock.with_exclusive do
      STDOUT.puts "locked"
      STDOUT.flush
      sleep 5
    end
  RUBY
  stdin, stdout, _stderr, waiter = ruby_child("#{holder_code}\n", [vault], "NOUS_LOCK_TIMEOUT" => "1")
  stdin.close
  pid = waiter.pid
  begin
    assert(stdout.gets&.strip == "locked", "child should acquire lock")
    error = assert_error("NOUS_LOCK_TIMEOUT", "cross-process lock should timeout while child holds it") do
      Nous::VaultLock.new(vault_root: vault, timeout: 0.2).with_exclusive { raise "should not acquire" }
    end
    assert(error.details.fetch(:timeout) == 0.2, "timeout detail should be bounded")
  ensure
    Process.kill("TERM", pid)
    waiter.value
  end
  Nous::VaultLock.new(vault_root: vault, timeout: 1).with_exclusive { assert(true, "lock should recover after process termination") }

  symlink_vault = tmpdir + "lock-symlink-vault"
  symlink_vault.mkpath
  write_file(tmpdir + "outside-lock-target", "")
  File.symlink((tmpdir + "outside-lock-target").to_s, (symlink_vault + ".nous.lock").to_s)
  assert_error("NOUS_SYMLINK_REJECTED", "lock file symlink should be rejected") do
    Nous::VaultLock.new(vault_root: symlink_vault, timeout: 0.1).with_exclusive { raise "should not acquire" }
  end

  previous_timeout = ENV["NOUS_LOCK_TIMEOUT"]
  ENV["NOUS_LOCK_TIMEOUT"] = "not-a-number"
  begin
    Nous::VaultLock.new(vault_root: vault).with_shared { assert(true, "lock should ignore ENV timeout") }
  ensure
    ENV["NOUS_LOCK_TIMEOUT"] = previous_timeout
  end
end

def test_atomic_writer(tmpdir)
  vault = tmpdir + "write-vault"
  vault.mkpath

  created = Nous::AtomicWriter.create(vault_root: vault, path: "04_generated/new.txt", bytes: "hello\n")
  assert(created.binread == "hello\n", "create should write exact bytes")
  assert_no_temps(vault)

  assert_error("NOUS_WRITE_FAILED", "create should not overwrite existing destination") do
    Nous::AtomicWriter.create(vault_root: vault, path: "04_generated/new.txt", bytes: "changed\n")
  end
  assert(created.binread == "hello\n", "failed create should preserve existing bytes")

  assert_error("NOUS_WRITE_FAILED", "create should not overwrite if destination appears during validation") do
    Nous::AtomicWriter.create(
      vault_root: vault,
      path: "04_generated/race.txt",
      bytes: "winner\n",
      validate: ->(_temp_path) { write_file(vault + "04_generated/race.txt", "racer\n") }
    )
  end
  assert((vault + "04_generated/race.txt").binread == "racer\n", "race-created destination should be preserved")

  replaced = Nous::AtomicWriter.replace(
    vault_root: vault,
    path: "04_generated/new.txt",
    bytes: "updated\n",
    validate: ->(temp_path) { raise Nous::Error.new("invalid", code: "NOUS_INVALID_INPUT") unless temp_path.binread == "updated\n" }
  )
  assert(replaced.binread == "updated\n", "replace should update after validation")

  assert_error("NOUS_INVALID_INPUT", "failed validation should preserve old output") do
    Nous::AtomicWriter.replace(
      vault_root: vault,
      path: "04_generated/new.txt",
      bytes: "bad\n",
      validate: ->(_temp_path) { raise Nous::Error.new("invalid", code: "NOUS_INVALID_INPUT") }
    )
  end
  assert(created.binread == "updated\n", "failed replace should preserve old output")
  assert_no_temps(vault)

  parent_file = vault + "blocked-parent"
  parent_file.binwrite("not a directory\n")
  error = assert_error("NOUS_WRITE_FAILED", "WRITE-C-005 parent file should fail with sanitized writer error") do
    Nous::AtomicWriter.create(vault_root: vault, path: "blocked-parent/child.txt", bytes: "x\n")
  end
  assert(error.message == "failed to finalize import", "parent-file error should be generic")
  assert(!error.message.include?(vault.to_s), "parent-file error should not leak vault path")
  assert(!error.message.include?(".tmp-nous-"), "parent-file error should not leak temp path")

  adapter_parent = tmpdir + "adapter-parent-file"
  adapter_parent.binwrite("not a directory\n")
  error = assert_error("NOUS_WRITE_FAILED", "adapter invalid destination should fail with sanitized writer error") do
    Nous::AtomicWriter.replace_adapter_path(path: adapter_parent + "child.txt", bytes: "x\n")
  end
  assert(error.message == "failed to finalize import", "adapter invalid destination error should be generic")
  assert(!error.message.include?(adapter_parent.to_s), "adapter invalid destination should not leak external path")

  unwritable = vault + "unwritable"
  unwritable.mkpath
  FileUtils.chmod(0o500, unwritable)
  begin
    error = assert_error("NOUS_WRITE_FAILED", "unwritable destination should fail with sanitized writer error") do
      Nous::AtomicWriter.create(vault_root: vault, path: "unwritable/child.txt", bytes: "x\n")
    end
    assert(error.message == "failed to finalize import", "unwritable destination error should be generic")
    assert(!error.message.include?(unwritable.to_s), "unwritable destination should not leak path")
  ensure
    FileUtils.chmod(0o700, unwritable)
  end

  staged = Nous::AtomicWriter.stage(vault_root: vault, path: "04_generated/staged.txt", bytes: "staged\n")
  resolved_vault = Nous::PathGuard.validate_vault_root(vault)
  assert(staged.temp_path.dirname == (resolved_vault + "04_generated"), "staging should be destination-local")
  staged.cleanup
  assert_no_temps(vault)

  temps = 20.times.map do
    Nous::AtomicWriter.stage(vault_root: vault, path: "04_generated/#{_1}.txt", bytes: "x").tap(&:cleanup).temp_path
  end
  assert(temps.uniq.length == temps.length, "temp names should be unique")
end

def test_file_transaction(tmpdir)
  vault = tmpdir + "tx-vault"
  vault.mkpath

  tx = Nous::FileTransaction.new(vault_root: vault)
  tx.stage(path: "00_raw_artifacts/files/source.txt", bytes: "payload\n")
  tx.stage(path: "00_raw_artifacts/artifacts/source.md", bytes: "---\nid: artifact\n---\n")
  tx.stage(path: "01_agent_inbox/notes/source.md", bytes: "---\nid: draft\n---\n")
  finals = tx.commit
  assert(finals.map { |path| Nous::PathGuard.relative_path(vault_root: vault, path: path) } == [
    "00_raw_artifacts/files/source.txt",
    "00_raw_artifacts/artifacts/source.md",
    "01_agent_inbox/notes/source.md"
  ], "transaction should finalize all outputs")
  assert_no_temps(vault)

  assert_error("NOUS_INVALID_INPUT", "staging validation failure should leave no files") do
    failed = Nous::FileTransaction.new(vault_root: vault)
    failed.stage(path: "00_raw_artifacts/files/bad.txt", bytes: "bad", validate: ->(_path) { raise Nous::Error.new("bad", code: "NOUS_INVALID_INPUT") })
  end
  assert(!(vault + "00_raw_artifacts/files/bad.txt").exist?, "failed staging should not create final")
  assert_no_temps(vault)

  failed = Nous::FileTransaction.new(vault_root: vault)
  earlier = failed.stage(path: "00_raw_artifacts/files/earlier.txt", bytes: "earlier")
  assert_error("NOUS_INVALID_INPUT", "later staging failure should rollback earlier staged temps") do
    failed.stage(path: "00_raw_artifacts/files/later.txt", bytes: "later", validate: ->(_path) { raise Nous::Error.new("later", code: "NOUS_INVALID_INPUT") })
  end
  assert(!earlier.temp_path.exist?, "earlier staged temp should be removed after later stage failure")
  assert(!(vault + "00_raw_artifacts/files/earlier.txt").exist?, "earlier final should not be created by stage rollback")
  assert(!(vault + "00_raw_artifacts/files/later.txt").exist?, "later final should not be created by failed stage")
  assert_no_temps(vault)

  rollback_vault = tmpdir + "tx-rollback-vault"
  rollback_vault.mkpath
  write_file(rollback_vault + "sentinel.md", "keep\n")
  failed = Nous::FileTransaction.new(vault_root: rollback_vault)
  first = failed.stage(path: "a.txt", bytes: "a\n")
  second = failed.stage(path: "b.txt", bytes: "b\n")
  def second.finalize(overwrite: false)
    raise Nous::Error.new("forced finalize failure", code: "NOUS_WRITE_FAILED")
  end

  assert_error("NOUS_WRITE_FAILED", "finalization failure should rollback invocation-created finals") do
    failed.commit
  end
  assert(!first.destination.exist?, "first invocation-created final should be removed")
  assert(!second.destination.exist?, "second final should not exist")
  assert((rollback_vault + "sentinel.md").binread == "keep\n", "pre-existing unrelated file should be preserved")
  assert_no_temps(rollback_vault)
end

def test_text_ingestion_core_success(tmpdir)
  source = tmpdir + "source.md"
  source.write("# Evening Reflection\n\nFocused writing helps me make decisions.\nI want tools that preserve context.")
  original_bytes = source.binread
  vault = tmpdir + "text-core-vault"

  result = nil
  stdout, stderr = capture_output do
    result = Nous::TextIngestion.ingest(
      source_path: source,
      vault_root: vault,
      date: "2026-06-14",
      source_display_base: ROOT
    )
  end

  assert(stdout.empty?, "text ingestion core should not write stdout")
  assert(stderr.empty?, "text ingestion core should not write stderr")
  assert(result == {
    artifact_id: "artifact_2026-06-14_source",
    draft_id: "note_2026-06-14_source",
    artifact_path: "00_raw_artifacts/text/artifact_2026-06-14_source.md",
    draft_path: "01_agent_inbox/notes/note_2026-06-14_source.md"
  }, "text ingestion core should return structured relative paths and ids")

  artifact = vault + result.fetch(:artifact_path)
  draft = vault + result.fetch(:draft_path)
  assert(artifact.file?, "artifact should be finalized")
  assert(draft.file?, "draft should be finalized")
  assert(source.binread == original_bytes, "source should be unchanged")
  assert_no_temps(vault)

  artifact_frontmatter = frontmatter(artifact)
  draft_frontmatter = frontmatter(draft)
  assert(Pathname(artifact_frontmatter["source"]["path"]).realpath == source.realpath, "artifact source path should preserve old display behavior")
  assert(draft_frontmatter["source"]["path"] == result.fetch(:artifact_path), "draft source should point to artifact")
  assert(draft_frontmatter["evidence"] == [{ "id" => result.fetch(:artifact_id), "path" => result.fetch(:artifact_path) }], "draft evidence should point to artifact")
  assert(draft.read.include?("- # Evening Reflection"), "draft facts should be extractive")
end

def test_text_ingestion_source_validation(tmpdir)
  vault = tmpdir + "source-validation-vault"

  assert_error("NOUS_UNSUPPORTED_SOURCE", "missing text source should fail") do
    Nous::TextIngestion.ingest(source_path: tmpdir + "missing.txt", vault_root: vault, date: "2026-06-14", source_display_base: ROOT)
  end

  directory = tmpdir + "directory.md"
  directory.mkdir
  assert_error("NOUS_UNSUPPORTED_SOURCE", "directory text source should fail") do
    Nous::TextIngestion.ingest(source_path: directory, vault_root: vault, date: "2026-06-14", source_display_base: ROOT)
  end

  unsupported = tmpdir + "capture.pdf"
  unsupported.write("not text")
  assert_error("NOUS_UNSUPPORTED_SOURCE", "unsupported text extension should fail") do
    Nous::TextIngestion.ingest(source_path: unsupported, vault_root: vault, date: "2026-06-14", source_display_base: ROOT)
  end

  empty = tmpdir + "empty.txt"
  empty.write("  \n")
  assert_error("NOUS_UNSUPPORTED_SOURCE", "empty text source should fail") do
    Nous::TextIngestion.ingest(source_path: empty, vault_root: vault, date: "2026-06-14", source_display_base: ROOT)
  end

  invalid = tmpdir + "invalid.txt"
  invalid.binwrite("\xFF")
  assert_error("NOUS_UNSUPPORTED_SOURCE", "invalid UTF-8 text source should fail") do
    Nous::TextIngestion.ingest(source_path: invalid, vault_root: vault, date: "2026-06-14", source_display_base: ROOT)
  end
end

def test_text_ingestion_forced_failure(tmpdir)
  source = tmpdir + "failure.txt"
  source.write("Failure fixture.\n")
  source_bytes = source.binread
  vault = tmpdir + "forced-failure-vault"

  assert_error("NOUS_WRITE_FAILED", "forced collaborator failure should rollback artifact and draft") do
    Nous::TextIngestion.ingest(
      source_path: source,
      vault_root: vault,
      date: "2026-06-14",
      source_display_base: ROOT,
      before_commit: -> { raise Nous::Error.new("forced collaborator failure", code: "NOUS_WRITE_FAILED") }
    )
  end

  assert(source.binread == source_bytes, "source should remain unchanged on failure")
  assert(!(vault + "00_raw_artifacts/text/artifact_2026-06-14_failure.md").exist?, "artifact final should not exist after forced failure")
  assert(!(vault + "01_agent_inbox/notes/note_2026-06-14_failure.md").exist?, "draft final should not exist after forced failure")
  assert_no_temps(vault)
end

def test_text_ingestion_concurrent_same_slug(tmpdir)
  source = tmpdir + "same slug.txt"
  source.write("Concurrent text import.\n")
  vault = tmpdir + "concurrent-text-vault"

  code = <<~RUBY
    require "nous"
    result = Nous::TextIngestion.ingest(
      source_path: ARGV.fetch(0),
      vault_root: ARGV.fetch(1),
      date: "2026-06-14",
      source_display_base: ARGV.fetch(2)
    )
    puts [result.fetch(:artifact_path), result.fetch(:draft_path)].join("\\t")
  RUBY

  children = 2.times.map { ruby_child(code, [source, vault, ROOT]) }
  results = []
  children.each do |stdin, stdout, stderr, waiter|
    stdin.close
    begin
      status = waiter.value
      child_stderr = stderr.read
      assert(status.success?, "concurrent text child should pass: #{child_stderr}")
      results << stdout.read.strip.split("\t")
    ensure
      begin
        Process.kill("TERM", waiter.pid) if waiter.alive?
      rescue Errno::ESRCH
        nil
      end
    end
  end

  artifact_paths = results.map(&:first)
  draft_paths = results.map(&:last)
  assert(artifact_paths.sort == [
    "00_raw_artifacts/text/artifact_2026-06-14_same-slug-2.md",
    "00_raw_artifacts/text/artifact_2026-06-14_same-slug.md"
  ], "concurrent artifact paths should be distinct")
  assert(draft_paths.sort == [
    "01_agent_inbox/notes/note_2026-06-14_same-slug-2.md",
    "01_agent_inbox/notes/note_2026-06-14_same-slug.md"
  ], "concurrent draft paths should be distinct")

  (artifact_paths + draft_paths).each do |relative|
    assert((vault + relative).file?, "concurrent output should exist: #{relative}")
  end
  assert_no_temps(vault)
end

def capture_output
  original_stdout = $stdout
  original_stderr = $stderr
  stdout_reader, stdout_writer = IO.pipe
  stderr_reader, stderr_writer = IO.pipe
  $stdout = stdout_writer
  $stderr = stderr_writer
  yield
  stdout_writer.close
  stderr_writer.close
  [stdout_reader.read, stderr_reader.read]
ensure
  $stdout = original_stdout
  $stderr = original_stderr
  stdout_writer&.close unless stdout_writer&.closed?
  stderr_writer&.close unless stderr_writer&.closed?
  stdout_reader&.close unless stdout_reader&.closed?
  stderr_reader&.close unless stderr_reader&.closed?
end

def test_text_ingestion(tmpdir)
  test_text_ingestion_core_success(tmpdir)
  test_text_ingestion_source_validation(tmpdir)
  test_text_ingestion_forced_failure(tmpdir)
  test_text_ingestion_concurrent_same_slug(tmpdir)
end

def artifact_markdown_files(vault)
  vault.find.select { |path| path.file? && path.extname == ".md" }
end

def assert_no_external_path_leak(vault, source)
  external = source.expand_path.to_s
  offenders = artifact_markdown_files(vault).select { |path| path.read.include?(external) }
  assert(offenders.empty?, "artifact ingestion should not serialize external source paths: #{offenders.map(&:to_s).join(", ")}")
end

def artifact_core_import(source, vault, type: "writing", date: "2026-07-04", **extra)
  Nous::ArtifactIngestion.ingest(
    source_path: source,
    vault_root: vault,
    type: type,
    date: date,
    context: "Synthetic context.",
    represented_date: "2026-06-30",
    **extra
  )
end

def test_artifact_ingestion_core_success(tmpdir)
  source = tmpdir + "M6 Journal.md"
  source.write("# M6 Fixture\n\nLine one preserves source wording.\nLine two stays extractive.\n")
  source_bytes = source.binread
  vault = tmpdir + "artifact-core-vault"

  result = nil
  stdout, stderr = capture_output do
    result = artifact_core_import(source, vault)
  end

  assert(stdout.empty?, "artifact core should not write stdout")
  assert(stderr.empty?, "artifact core should not write stderr")
  assert(result.fetch(:copied_source_path) == "00_raw_artifacts/writing/files/m6-journal.md", "copied source path should be vault-relative")
  assert(result.fetch(:artifact_path) == "00_raw_artifacts/writing/notes/artifact_2026-07-04_m6-journal.md", "artifact path should be vault-relative")
  assert(result.fetch(:draft_path) == "01_agent_inbox/notes/note_2026-07-04_m6-journal.md", "draft path should be vault-relative")
  assert((vault + result.fetch(:copied_source_path)).binread == source_bytes, "copied payload bytes should match source")
  assert(source.binread == source_bytes, "source should be preserved")
  assert(frontmatter(vault + result.fetch(:artifact_path))["source"]["path"] == result.fetch(:copied_source_path), "artifact should point to copied payload")
  assert(frontmatter(vault + result.fetch(:draft_path))["evidence"] == [{ "id" => result.fetch(:artifact_id), "path" => result.fetch(:artifact_path) }], "draft evidence should point to artifact")
  assert_no_external_path_leak(vault, source)
  assert_no_temps(vault)
end

def test_artifact_ingestion_invalid_type_and_sanitized_errors(tmpdir)
  source = tmpdir + "Invalid Type.txt"
  source.write("Invalid type source.\n")
  error = assert_error("NOUS_UNSUPPORTED_SOURCE", "invalid direct artifact type should raise Nous::Error") do
    artifact_core_import(source, tmpdir + "artifact-invalid-type-vault", type: "audio")
  end
  assert(error.message.include?("unsupported type"), "invalid type error should explain supported types")

  missing = tmpdir + "missing-secret.txt"
  error = assert_error("NOUS_UNSUPPORTED_SOURCE", "direct artifact source error should be sanitized") do
    artifact_core_import(missing, tmpdir + "artifact-missing-vault")
  end
  assert(!error.message.include?(tmpdir.to_s), "direct artifact source error should not expose external absolute path")
end

def test_artifact_ingestion_binary_metadata_only(tmpdir)
  source = tmpdir + "Photo.PNG"
  source.binwrite("\x89PNG\r\n\x1A\nm6-image-bytes\x00\xFF".b)
  vault = tmpdir + "artifact-image-vault"
  result = artifact_core_import(source, vault, type: "image", represented_date: nil)
  artifact = vault + result.fetch(:artifact_path)
  draft = vault + result.fetch(:draft_path)

  assert(markdown_section(artifact, "Observed Content").empty?, "binary artifact should have empty observed content")
  assert(draft.read.include?("- Imported image artifact metadata only."), "binary draft should be metadata-only")
  assert_no_external_path_leak(vault, source)
end

def test_artifact_ingestion_lock_timeout_before_copy(tmpdir)
  source = tmpdir + "Locked.txt"
  source.write("Locked source remains untouched.\n")
  source_bytes = source.binread
  vault = tmpdir + "artifact-lock-timeout-vault"
  Nous::ArtifactIngestion.prepare_vault_root(vault)

  Nous::VaultLock.new(vault_root: vault, timeout: 1).with_exclusive do
    code = <<~RUBY
      require "nous"
      begin
        Nous::ArtifactIngestion.ingest(
          source_path: ARGV.fetch(0),
          vault_root: ARGV.fetch(1),
          type: "writing",
          date: "2026-07-04",
          lock_timeout: 0.1
        )
      rescue Nous::Error => error
        STDOUT.puts error.code
      end
    RUBY
    stdout, stderr, status = Open3.capture3({ "RUBYLIB" => LIB.to_s }, "ruby", "-e", code, source.to_s, vault.to_s)
    assert(status.success?, "artifact lock timeout child should exit cleanly: #{stderr}")
    assert(stdout.strip == "NOUS_LOCK_TIMEOUT", "artifact ingestion should timeout before copy")
  end

  assert(source.binread == source_bytes, "source should be unchanged after lock timeout")
  finals = vault.find.select(&:file?).reject { |path| path.basename.to_s == ".nous.lock" }
  assert(finals.empty?, "lock timeout should not create outputs: #{finals.map(&:to_s).join(", ")}")
end

def test_artifact_ingestion_forced_failures(tmpdir)
  source = tmpdir + "Failure.txt"
  source.write("Failure source.\n")
  source_bytes = source.binread

  checksum_vault = tmpdir + "artifact-checksum-failure-vault"
  assert_error("NOUS_WRITE_FAILED", "checksum failure should rollback all temps") do
    artifact_core_import(
      source,
      checksum_vault,
      payload_validator: ->(_temp_path) { raise Nous::Error.new("copied payload failed checksum verification", code: "NOUS_WRITE_FAILED") }
    )
  end
  assert(source.binread == source_bytes, "checksum failure should preserve source")
  assert_no_temps(checksum_vault)
  assert(checksum_vault.find.select(&:file?).reject { |path| path.basename.to_s == ".nous.lock" }.empty?, "checksum failure should leave no outputs")

  [1, 2].each do |finalized_count|
    vault = tmpdir + "artifact-finalize-#{finalized_count}-failure-vault"
    assert_error("NOUS_WRITE_FAILED", "failure after finalize #{finalized_count} should rollback invocation-created finals") do
      artifact_core_import(
        source,
        vault,
        after_finalize: lambda do |count, _path|
          raise Nous::Error.new("forced finalize failure", code: "NOUS_WRITE_FAILED") if count == finalized_count
        end
      )
    end
    assert(source.binread == source_bytes, "finalize failure should preserve source")
    assert_no_temps(vault)
    finals = vault.find.select(&:file?).reject { |path| path.basename.to_s == ".nous.lock" }
    assert(finals.empty?, "failure after finalize #{finalized_count} should remove created outputs: #{finals.map(&:to_s).join(", ")}")
  end
end

def run_artifact_children(source_args)
  code = <<~RUBY
    require "nous"
    result = Nous::ArtifactIngestion.ingest(
      source_path: ARGV.fetch(0),
      vault_root: ARGV.fetch(1),
      type: "writing",
      date: "2026-07-04"
    )
    puts [result.fetch(:copied_source_path), result.fetch(:artifact_path), result.fetch(:draft_path)].join("\\t")
  RUBY
  children = source_args.map { |source, vault| ruby_child(code, [source, vault]) }
  children.map do |stdin, stdout, stderr, waiter|
    stdin.close
    status = waiter.value
    child_stderr = stderr.read
    assert(status.success?, "artifact child should pass: #{child_stderr}")
    stdout.read.strip.split("\t")
  ensure
    begin
      Process.kill("TERM", waiter.pid) if waiter&.alive?
    rescue Errno::ESRCH
      nil
    end
  end
end

def test_artifact_ingestion_concurrency(tmpdir)
  source = tmpdir + "Same Source.txt"
  source.write("Concurrent same source.\n")
  vault = tmpdir + "artifact-same-source-vault"
  same_source_results = run_artifact_children([[source, vault], [source, vault]])
  assert(same_source_results.map(&:first).sort == [
    "00_raw_artifacts/writing/files/same-source-2.txt",
    "00_raw_artifacts/writing/files/same-source.txt"
  ], "same-source payload paths should be distinct")
  assert(same_source_results.map { |row| row[1] }.sort == [
    "00_raw_artifacts/writing/notes/artifact_2026-07-04_same-source-2.md",
    "00_raw_artifacts/writing/notes/artifact_2026-07-04_same-source.md"
  ], "same-source artifact paths should be distinct")
  same_source_results.flatten.each { |relative| assert((vault + relative).file?, "concurrent same-source output missing: #{relative}") }
  assert_no_temps(vault)

  source_a = tmpdir + "Same Slug.txt"
  source_b = tmpdir + "same--slug.md"
  source_a.write("Concurrent same slug A.\n")
  source_b.write("Concurrent same slug B.\n")
  slug_vault = tmpdir + "artifact-same-slug-vault"
  same_slug_results = run_artifact_children([[source_a, slug_vault], [source_b, slug_vault]])
  assert(same_slug_results.map { |row| row[1] }.sort == [
    "00_raw_artifacts/writing/notes/artifact_2026-07-04_same-slug-2.md",
    "00_raw_artifacts/writing/notes/artifact_2026-07-04_same-slug.md"
  ], "same-slug artifact records should share suffix allocation")
  same_slug_results.flatten.each { |relative| assert((slug_vault + relative).file?, "concurrent same-slug output missing: #{relative}") }
  assert_no_temps(slug_vault)
end

def test_artifact_ingestion(tmpdir)
  test_artifact_ingestion_core_success(tmpdir)
  test_artifact_ingestion_invalid_type_and_sanitized_errors(tmpdir)
  test_artifact_ingestion_binary_metadata_only(tmpdir)
  test_artifact_ingestion_lock_timeout_before_copy(tmpdir)
  test_artifact_ingestion_forced_failures(tmpdir)
  test_artifact_ingestion_concurrency(tmpdir)
end

def review_frontmatter(id, type, extra = {})
  {
    "id" => id,
    "type" => type,
    "schema_version" => "0.1",
    "status" => "draft",
    "review_status" => "agent_generated",
    "confidence" => 0.7,
    "created" => "2026-06-01",
    "updated" => "2026-06-01",
    "source" => { "type" => "text", "path" => "00_raw_artifacts/text/artifact_review.md", "extraction_method" => "archivist_agent" },
    "evidence" => [{ "id" => "artifact_review", "path" => "00_raw_artifacts/text/artifact_review.md" }],
    "counterevidence" => [],
    "tags" => []
  }.merge(extra)
end

def review_fixture(vault)
  write_note(
    vault + "00_raw_artifacts/text/artifact_review.md",
    review_frontmatter("artifact_review", "artifact", "review_status" => "needs_review"),
    "# Artifact\n\nRaw evidence.\n"
  )
  note = vault + "01_agent_inbox/notes/note_review.md"
  claim = vault + "01_agent_inbox/claims/claim_review.md"
  relationship = vault + "01_agent_inbox/relationships/edge_review.md"
  write_note(note, review_frontmatter("note_review", "note"), "# Note\n\nBody.\n")
  write_note(claim, review_frontmatter("claim_review", "claim", "review_status" => "needs_review"), "# Claim\n\nBody.\n")
  write_note(
    relationship,
    review_frontmatter(
      "edge_review",
      "relationship",
      "relationship" => { "from" => "note_review", "to" => "claim_review", "type" => "supports" }
    ),
    "# Relationship\n\nBody.\n"
  )
  { note: note, claim: claim, relationship: relationship }
end

def test_review_mutation_direct(tmpdir)
  timestamp = "2026-06-28T21:00:00Z"

  vault = tmpdir + "review-direct-vault"
  fixture = review_fixture(vault)
  result = Nous::ReviewMutation.reject(path: fixture.fetch(:claim), vault_root: vault, timestamp: timestamp, reviewer_note: "Nope.")
  assert(result == { decision: "rejected", source_path: "01_agent_inbox/claims/claim_review.md" }, "reject should return structured result")
  rejected = frontmatter(fixture.fetch(:claim))
  assert(rejected["status"] == "archived", "reject should archive source")
  assert(rejected["review_status"] == "rejected", "reject review status is wrong")
  assert(rejected["review"]["reviewer_note"] == "Nope.", "reject should preserve reviewer note")

  vault = tmpdir + "review-deprecate-vault"
  fixture = review_fixture(vault)
  Nous::ReviewMutation.deprecate(path: fixture.fetch(:relationship), vault_root: vault, timestamp: timestamp)
  deprecated = frontmatter(fixture.fetch(:relationship))
  assert(deprecated["status"] == "archived", "deprecate should archive source")
  assert(deprecated["review_status"] == "deprecated", "deprecate review status is wrong")

  vault = tmpdir + "review-approve-vault"
  fixture = review_fixture(vault)
  note_result = Nous::ReviewMutation.approve(path: fixture.fetch(:note), vault_root: vault, timestamp: timestamp, note_type: "memory")
  claim_result = Nous::ReviewMutation.approve(path: fixture.fetch(:claim), vault_root: vault, timestamp: timestamp)
  assert(note_result.fetch(:destination_path) == "02_notes/memories/note_review.md", "note approval destination is wrong")
  assert(claim_result.fetch(:destination_path) == "03_canonical_model/claims/claim_review.md", "claim approval destination is wrong")
  assert(!(fixture.fetch(:note)).exist?, "approved note should leave inbox")
  assert(!(fixture.fetch(:claim)).exist?, "approved claim should leave inbox")
  assert(frontmatter(vault + "02_notes/memories/note_review.md")["type"] == "memory", "approved note type is wrong")

  rel_result = Nous::ReviewMutation.approve(path: fixture.fetch(:relationship), vault_root: vault, timestamp: timestamp)
  assert(rel_result.fetch(:destination_path) == "03_canonical_model/relationships/edge_review.md", "relationship approval destination is wrong")

  collision_vault = tmpdir + "review-collision-vault"
  collision = review_fixture(collision_vault)
  sentinel = collision_vault + "03_canonical_model/claims/claim_review.md"
  write_note(sentinel, review_frontmatter("sentinel", "claim", "status" => "active", "review_status" => "reviewed"), "# Sentinel\n")
  before_source = collision.fetch(:claim).binread
  before_dest = sentinel.binread
  assert_error("NOUS_WRITE_FAILED", "destination collision should fail") do
    Nous::ReviewMutation.approve(path: collision.fetch(:claim), vault_root: collision_vault, timestamp: timestamp)
  end
  assert(collision.fetch(:claim).binread == before_source, "collision should preserve source bytes")
  assert(sentinel.binread == before_dest, "collision should preserve destination bytes")

  rollback_vault = tmpdir + "review-approve-rollback-vault"
  rollback = review_fixture(rollback_vault)
  rollback_source = rollback.fetch(:claim)
  rollback_destination = rollback_vault + "03_canonical_model/claims/claim_review.md"
  source_before = rollback_source.binread
  assert_error("NOUS_WRITE_FAILED", "approve failure before move should restore source and leave destination absent") do
    Nous::ReviewMutation.approve(
      path: rollback_source,
      vault_root: rollback_vault,
      timestamp: timestamp,
      after_stage: -> { raise Nous::Error.new("forced before move", code: "NOUS_WRITE_FAILED") }
    )
  end
  assert(rollback_source.file?, "approve rollback should keep source in inbox")
  assert(rollback_source.binread == source_before, "approve rollback should restore original source bytes")
  assert(!rollback_destination.exist?, "approve rollback should not leave destination")
end

def test_review_merge_and_boundaries(tmpdir)
  timestamp = "2026-06-28T21:00:00Z"
  vault = tmpdir + "review-merge-vault"
  fixture = review_fixture(vault)
  target = vault + "02_notes/memories/target.md"
  write_note(
    target,
    review_frontmatter("target", "memory", "status" => "active", "review_status" => "reviewed", "evidence" => [{ "id" => "existing", "path" => "existing.md" }]),
    "# Target\n\nBody.\n"
  )
  result = Nous::ReviewMutation.merge(path: fixture.fetch(:note), vault_root: vault, target_path: target, timestamp: timestamp)
  assert(result == { decision: "merged", source_path: "01_agent_inbox/notes/note_review.md", target_path: "02_notes/memories/target.md" }, "merge result is wrong")
  assert(frontmatter(fixture.fetch(:note))["status"] == "archived", "merge should archive source")
  evidence = frontmatter(target)["evidence"]
  assert(evidence.include?({ "id" => "existing", "path" => "existing.md" }), "merge should preserve target evidence")
  assert(evidence.include?({ "id" => "note_review", "path" => "01_agent_inbox/notes/note_review.md" }), "merge should add source provenance")

  rollback_vault = tmpdir + "review-merge-rollback-vault"
  rollback = review_fixture(rollback_vault)
  rollback_target = rollback_vault + "02_notes/memories/target.md"
  write_note(rollback_target, review_frontmatter("target", "memory", "status" => "active", "review_status" => "reviewed"), "# Target\n")
  source_before = rollback.fetch(:note).binread
  target_before = rollback_target.binread
  assert_error("NOUS_WRITE_FAILED", "merge failure after first replacement should rollback both files") do
    Nous::ReviewMutation.merge(
      path: rollback.fetch(:note),
      vault_root: rollback_vault,
      target_path: rollback_target,
      timestamp: timestamp,
      after_first_replace: -> { raise Nous::Error.new("forced merge failure", code: "NOUS_WRITE_FAILED") }
    )
  end
  assert(rollback.fetch(:note).binread == source_before, "merge rollback should restore source")
  assert(rollback_target.binread == target_before, "merge rollback should restore target")

  outside = tmpdir + "outside.md"
  write_note(outside, review_frontmatter("outside", "memory", "status" => "active", "review_status" => "reviewed"))
  assert_error("NOUS_INVALID_INPUT", "external merge target should be rejected") do
    Nous::ReviewMutation.merge(path: rollback.fetch(:note), vault_root: rollback_vault, target_path: outside, timestamp: timestamp)
  end
  symlink = rollback_vault + "02_notes/memories/link.md"
  File.symlink(outside.to_s, symlink.to_s)
  assert_error("NOUS_INVALID_INPUT", "symlink merge target should be rejected") do
    Nous::ReviewMutation.merge(path: rollback.fetch(:note), vault_root: rollback_vault, target_path: symlink, timestamp: timestamp)
  end

  missing_item = tmpdir + "private/missing-review-item.md"
  error = assert_error("NOUS_RECORD_NOT_FOUND", "missing external review item should be sanitized") do
    Nous::ReviewMutation.resolve_for_edit(path: missing_item, vault_root: rollback_vault)
  end
  assert(error.message == "review item does not exist", "missing review item error should be generic")
  assert(!error.message.include?(tmpdir.to_s), "missing review item error should not leak an external path")

  missing_target = tmpdir + "private/missing-merge-target.md"
  error = assert_error("NOUS_RECORD_NOT_FOUND", "missing external merge target should be sanitized") do
    Nous::ReviewMutation.merge(
      path: rollback.fetch(:note),
      vault_root: rollback_vault,
      target_path: missing_target,
      timestamp: timestamp
    )
  end
  assert(error.message == "merge target does not exist", "missing merge target error should be generic")
  assert(!error.message.include?(tmpdir.to_s), "missing merge target error should not leak an external path")
end

def write_endpoint(vault, relative, id, type, status: "active", review_status: "reviewed")
  write_note(vault + relative, review_frontmatter(id, type, "status" => status, "review_status" => review_status), "# #{id}\n")
end

def write_relationship_candidate(vault, from_id, to_id)
  path = vault + "01_agent_inbox/relationships/edge.md"
  write_note(
    path,
    review_frontmatter("edge", "relationship", "relationship" => { "from" => from_id, "to" => to_id, "type" => "supports" }),
    "# Edge\n"
  )
  path
end

def assert_relationship_blocked(vault, from_id, to_id, code = "NOUS_REVIEW_REQUIRED")
  relationship = write_relationship_candidate(vault, from_id, to_id)
  before = relationship.binread
  assert_error(code, "relationship should be blocked for #{from_id.inspect} -> #{to_id.inspect}") do
    Nous::ReviewMutation.approve(path: relationship, vault_root: vault, timestamp: "2026-06-28T21:00:00Z")
  end
  assert(relationship.binread == before, "blocked relationship approval should preserve source bytes")
end

def test_relationship_integrity(tmpdir)
  timestamp = "2026-06-28T21:00:00Z"
  vault = tmpdir + "relationship-good-vault"
  write_endpoint(vault, "02_notes/memories/note_a.md", "note_a", "memory")
  write_endpoint(vault, "03_canonical_model/claims/claim_a.md", "claim_a", "claim")
  relationship = write_relationship_candidate(vault, "note_a", "claim_a")
  Nous::ReviewMutation.approve(path: relationship, vault_root: vault, timestamp: timestamp)
  assert((vault + "03_canonical_model/relationships/edge.md").file?, "valid relationship should approve")

  [
    ["02_notes/projects/project_a.md", "project_a", "project"],
    ["02_notes/decisions/decision_a.md", "decision_a", "decision"],
    ["02_notes/people/person_a.md", "person_a", "person"]
  ].each do |relative, id, type|
    expanded_vault = tmpdir + "relationship-#{type}-endpoint-vault"
    write_endpoint(expanded_vault, relative, id, type)
    write_endpoint(expanded_vault, "03_canonical_model/claims/claim_a.md", "claim_a", "claim")
    expanded_relationship = write_relationship_candidate(expanded_vault, id, "claim_a")
    Nous::ReviewMutation.approve(path: expanded_relationship, vault_root: expanded_vault, timestamp: timestamp)
    assert((expanded_vault + "03_canonical_model/relationships/edge.md").file?, "valid #{type} relationship endpoint should approve")
  end

  pending_vault = tmpdir + "relationship-pending-vault"
  write_endpoint(pending_vault, "01_agent_inbox/notes/note_a.md", "note_a", "memory", status: "draft", review_status: "reviewed")
  write_endpoint(pending_vault, "01_agent_inbox/claims/claim_a.md", "claim_a", "claim", status: "draft", review_status: "needs_review")
  assert_relationship_blocked(pending_vault, "note_a", "claim_a")

  raw_vault = tmpdir + "relationship-raw-vault"
  write_endpoint(raw_vault, "00_raw_artifacts/text/artifact_a.md", "artifact_a", "artifact", status: "draft", review_status: "needs_review")
  write_endpoint(raw_vault, "03_canonical_model/claims/claim_a.md", "claim_a", "claim")
  assert_relationship_blocked(raw_vault, "artifact_a", "claim_a")

  rel_endpoint_vault = tmpdir + "relationship-endpoint-vault"
  write_endpoint(rel_endpoint_vault, "03_canonical_model/relationships/edge_a.md", "edge_a", "relationship")
  write_endpoint(rel_endpoint_vault, "03_canonical_model/claims/claim_a.md", "claim_a", "claim")
  assert_relationship_blocked(rel_endpoint_vault, "edge_a", "claim_a")

  retired_vault = tmpdir + "relationship-retired-vault"
  write_endpoint(retired_vault, "02_notes/memories/note_a.md", "note_a", "memory", status: "archived", review_status: "reviewed")
  write_endpoint(retired_vault, "03_canonical_model/claims/claim_a.md", "claim_a", "claim")
  assert_relationship_blocked(retired_vault, "note_a", "claim_a")

  malformed_type_vault = tmpdir + "relationship-malformed-type-vault"
  write_endpoint(malformed_type_vault, "02_notes/memories/note_a.md", "note_a", "project")
  write_endpoint(malformed_type_vault, "03_canonical_model/claims/claim_a.md", "claim_a", "claim")
  assert_relationship_blocked(malformed_type_vault, "note_a", "claim_a")

  missing_vault = tmpdir + "relationship-missing-vault"
  write_endpoint(missing_vault, "03_canonical_model/claims/claim_a.md", "claim_a", "claim")
  assert_relationship_blocked(missing_vault, "missing", "claim_a")

  duplicate_vault = tmpdir + "relationship-duplicate-vault"
  write_endpoint(duplicate_vault, "02_notes/memories/note_a.md", "dup", "memory")
  write_endpoint(duplicate_vault, "03_canonical_model/claims/dup.md", "dup", "claim")
  write_endpoint(duplicate_vault, "03_canonical_model/claims/claim_a.md", "claim_a", "claim")
  assert_relationship_blocked(duplicate_vault, "dup", "claim_a", "NOUS_DUPLICATE_ID")

  progressive_vault = tmpdir + "relationship-progressive-vault"
  progressive = review_fixture(progressive_vault)
  assert_relationship_blocked(progressive_vault, "note_review", "claim_review")
  Nous::ReviewMutation.approve(path: progressive.fetch(:note), vault_root: progressive_vault, timestamp: timestamp, note_type: "memory")
  assert_relationship_blocked(progressive_vault, "note_review", "claim_review")
  Nous::ReviewMutation.approve(path: progressive.fetch(:claim), vault_root: progressive_vault, timestamp: timestamp)
  Nous::ReviewMutation.approve(path: progressive.fetch(:relationship), vault_root: progressive_vault, timestamp: timestamp)
  assert((progressive_vault + "03_canonical_model/relationships/edge_review.md").file?, "relationship should approve after both endpoints")

  graph_vault = tmpdir + "relationship-graph-defense-vault"
  write_endpoint(graph_vault, "02_notes/memories/note_a.md", "note_a", "memory")
  write_note(
    graph_vault + "03_canonical_model/relationships/bad.md",
    review_frontmatter("bad", "relationship", "status" => "active", "review_status" => "reviewed", "relationship" => { "from" => "note_a", "to" => "missing", "type" => "supports" }),
    "# Bad\n"
  )
  assert_error("NOUS_INVALID_ENDPOINT", "graph should retain endpoint defense") do
    Nous::Graph.build(vault_root: graph_vault, generated_at: "2026-06-28T21:00:00Z")
  end
end

def test_review_concurrent_decision(tmpdir)
  vault = tmpdir + "review-concurrent-vault"
  fixture = review_fixture(vault)
  code = <<~RUBY
    require "nous"
    begin
      if ARGV.fetch(0) == "approve"
        result = Nous::ReviewMutation.approve(path: ARGV.fetch(1), vault_root: ARGV.fetch(2), timestamp: "2026-06-28T21:00:00Z")
      else
        result = Nous::ReviewMutation.reject(path: ARGV.fetch(1), vault_root: ARGV.fetch(2), timestamp: "2026-06-28T21:00:00Z")
      end
      puts "ok:\#{result.fetch(:decision)}"
    rescue Nous::Error => error
      puts "err:\#{error.code}"
    end
  RUBY
  children = [
    ruby_child(code, ["approve", fixture.fetch(:claim), vault]),
    ruby_child(code, ["reject", fixture.fetch(:claim), vault])
  ]
  outcomes = children.map do |stdin, stdout, _stderr, waiter|
    stdin.close
    waiter.value
    stdout.read.strip
  end
  assert(outcomes.count { |outcome| outcome.start_with?("ok:") } == 1, "only one concurrent decision should succeed: #{outcomes.inspect}")
end

def test_review_mutations(tmpdir)
  test_review_mutation_direct(tmpdir)
  test_review_merge_and_boundaries(tmpdir)
  test_relationship_integrity(tmpdir)
  test_review_concurrent_decision(tmpdir)
end

def run_script_command(script_name, *args)
  scripts = {
    graph: ROOT + "scripts/export_graph.rb",
    report: ROOT + "scripts/generate_nous_report.rb",
    review: ROOT + "scripts/review_queue.rb"
  }
  Open3.capture3("ruby", scripts.fetch(script_name).to_s, *args.map(&:to_s))
end

def test_coherent_read_and_derived_locking(tmpdir)
  vault = tmpdir + "coherent-vault"
  lock_code = <<~RUBY
    require "pathname"
    require "psych"
    require "nous"
    def yaml_frontmatter(data)
      Psych.dump(data).sub(/\\A---\\n/, "")
    end
    def write_note(path, frontmatter, body)
      path.dirname.mkpath
      path.write("---\\n\#{yaml_frontmatter(frontmatter)}---\\n\\n\#{body}")
    end
    vault = Pathname(ARGV.fetch(0))
    mode = ARGV.fetch(1)
    Nous::ArtifactIngestion.prepare_vault_root(vault)
    Nous::VaultLock.new(vault_root: vault, timeout: 1).with_exclusive do
      STDOUT.puts "locked"
      STDOUT.flush
      sleep 0.4
      case mode
      when "graph"
        write_note(
          vault + "02_notes/memories/coherent.md",
          {
            "id" => "coherent_memory",
            "type" => "memory",
            "schema_version" => "0.1",
            "status" => "active",
            "review_status" => "reviewed",
            "confidence" => 0.8,
            "created" => "2026-06-01",
            "updated" => "2026-06-01",
            "evidence" => []
          },
          "# Coherent Memory\\n\\nVisible after lock release.\\n"
        )
      when "review"
        write_note(
          vault + "01_agent_inbox/claims/pending.md",
          {
            "id" => "pending_claim",
            "type" => "claim",
            "schema_version" => "0.1",
            "status" => "draft",
            "review_status" => "needs_review",
            "confidence" => 0.9,
            "created" => "2026-06-01",
            "updated" => "2026-06-01",
            "evidence" => []
          },
          "# Pending Claim\\n"
        )
      end
    end
  RUBY

  graph_output = tmpdir + "coherent-graph.json"
  stdin, stdout, stderr, waiter = ruby_child(lock_code, [vault, "graph"])
  stdin.close
  assert(stdout.gets&.strip == "locked", "graph lock holder should start")
  started = Time.now
  graph_stdout, graph_stderr, graph_status = run_script_command(:graph, "--vault-root", vault, "--output", graph_output)
  elapsed = Time.now - started
  assert(graph_status.success?, "graph command should pass after waiting: #{graph_stderr}")
  assert(elapsed >= 0.3, "graph command should wait behind exclusive lock")
  assert(graph_output.read.include?("coherent_memory"), "graph should observe post-lock complete state")
  assert(graph_stdout.include?("graph:"), "graph command should preserve stdout")
  waiter.value
  assert(stderr.read.empty?, "graph lock holder should not write stderr")

  report_output = tmpdir + "coherent-report.md"
  stdin, stdout, stderr, waiter = ruby_child(lock_code, [vault, "graph"])
  stdin.close
  assert(stdout.gets&.strip == "locked", "report lock holder should start")
  started = Time.now
  report_stdout, report_stderr, report_status = run_script_command(:report, "--vault-root", vault, "--output", report_output)
  elapsed = Time.now - started
  assert(report_status.success?, "report command should pass after waiting: #{report_stderr}")
  assert(elapsed >= 0.3, "report command should wait behind exclusive lock")
  assert(report_output.read.include?("coherent_memory"), "report should observe post-lock complete state")
  assert(report_stdout.include?("report:"), "report command should preserve stdout")
  waiter.value
  assert(stderr.read.empty?, "report lock holder should not write stderr")

  review_vault = tmpdir + "coherent-review-vault"
  stdin, stdout, stderr, waiter = ruby_child(lock_code, [review_vault, "review"])
  stdin.close
  assert(stdout.gets&.strip == "locked", "review list lock holder should start")
  started = Time.now
  list_stdout, list_stderr, list_status = run_script_command(:review, "list", "--vault-root", review_vault)
  elapsed = Time.now - started
  assert(list_status.success?, "review list should pass after waiting: #{list_stderr}")
  assert(elapsed >= 0.3, "review list should wait behind exclusive lock")
  assert(list_stdout.include?("01_agent_inbox/claims/pending.md"), "review list should observe post-lock complete state")
  waiter.value
  assert(stderr.read.empty?, "review lock holder should not write stderr")
end

Dir.mktmpdir("nous-mutation-core-test-") do |dir|
  tmpdir = Pathname(dir)
  focus = ARGV.first
  if focus.nil?
    test_path_guard(tmpdir)
    test_vault_lock(tmpdir)
    test_atomic_writer(tmpdir)
    test_file_transaction(tmpdir)
    test_text_ingestion(tmpdir)
    test_artifact_ingestion(tmpdir)
    test_review_mutations(tmpdir)
    test_coherent_read_and_derived_locking(tmpdir)
  elsif focus == "--text"
    test_text_ingestion(tmpdir)
  elsif focus == "--artifact"
    test_artifact_ingestion(tmpdir)
  elsif focus == "--write"
    test_atomic_writer(tmpdir)
  elsif focus == "--review"
    test_review_mutations(tmpdir)
  elsif focus == "--coherent"
    test_coherent_read_and_derived_locking(tmpdir)
  else
    raise "unsupported focus flag: #{focus}"
  end
end

puts "nous mutation core tests ok"
