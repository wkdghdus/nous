.PHONY: lint test

lint:
	./scripts/lint.sh

test:
	ruby scripts/test_ingest_text.rb
	ruby scripts/test_ingest_artifact.rb
	ruby scripts/test_review_queue.rb
	ruby scripts/test_export_graph.rb
	ruby scripts/test_generate_nous_report.rb
