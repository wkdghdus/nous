.PHONY: lint test

lint:
	./scripts/lint.sh

test:
	ruby scripts/test_ingest_text.rb
