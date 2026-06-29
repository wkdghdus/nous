# Test Spec: M3 Review Queue

## Required Checks

- `ruby scripts/test_review_queue.rb`
- `make test`
- `make lint`

## Regression Coverage

- Temporary vault fixture setup for pending note, claim, relationship, and referenced evidence files.
- Queue listing includes pending inbox items only and exposes kind, status, created date, confidence, evidence/source, and priority.
- Queue ordering works for created date and confidence.
- `show` prints frontmatter, body, source, and evidence paths without changing the file.
- Note approval requires `--as TYPE`; invalid note types fail; valid types move to `vault/02_notes/<type>/` with reviewed metadata.
- Claim approval moves to `vault/03_canonical_model/claims/`.
- Relationship approval moves to `vault/03_canonical_model/relationships/`.
- Approval fails when destination already exists.
- Reject and deprecate keep the file in place, set `review_status`, archive status, decision timestamp, and optional reviewer note, then remove the item from pending queue output.
- Merge requires `--into PATH`, preserves source file, records merge destination and reviewer note, and removes the source from pending queue output.
- Report generation writes only live pending items to `vault/04_generated/reports/review_queue.md`.

## Manual Inspection

Inspect fixture outputs after tests cover:

- One approved note destination.
- One approved claim destination.
- One approved relationship destination.
- One rejected or deprecated source file.
- The regenerated review queue report.
