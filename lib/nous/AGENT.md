# Nous Core Signpost

Use this directory for cohesive Nous Core files when the library outgrows the single `lib/nous.rb` entrypoint.

M7B intentionally keeps the read-only core compact in `lib/nous.rb`; do not add mutation, MCP, agent-write, lock, or network code here.
