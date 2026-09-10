.PHONY: lint test test-core test-mcp

lint:
	./scripts/lint.sh

test: test-core test-mcp

test-core:
	ruby scripts/test_nous_candidate_writes.rb
	ruby scripts/test_nous_agent_reads.rb
	ruby scripts/test_cli_contracts.rb
	ruby scripts/test_nous_read_core.rb
	ruby scripts/test_nous_mutation_core.rb
	ruby scripts/test_ingest_text.rb
	ruby scripts/test_ingest_artifact.rb
	ruby scripts/test_review_queue.rb
	ruby scripts/test_export_graph.rb
	ruby scripts/test_generate_nous_report.rb

test-mcp:
	bundle exec ruby scripts/test_nous_mcp.rb
