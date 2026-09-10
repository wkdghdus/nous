# frozen_string_literal: true

module Nous
  module CandidateWrites
    OP_CAPTURE = "nous_capture_user_text"
    OP_NOTE = "nous_propose_note"
    OP_CLAIM = "nous_propose_claim"
    OP_RELATIONSHIP = "nous_propose_relationship"
    ID_MAX_LENGTH = 200

    module_function

    def capture_user_text(vault_root:, request_id:, confirmed_user_authored:, user_text:, generated_at:, title: nil,
                          user_context: nil, represented_date: nil, lock_timeout: nil, before_stage: nil,
                          after_stage: nil, after_finalize: nil)
      Idempotency.validate_request_id!(request_id)
      invalid!("confirmed_user_authored must be true") unless confirmed_user_authored == true
      text = CandidateValidation.required_string!("user_text", user_text, max: CandidateValidation::CAPTURE_TEXT_MAX_LENGTH)
      invalid!("user_text exceeds 1 MiB") if text.bytesize > CandidateValidation::CAPTURE_TEXT_MAX_LENGTH
      normalized_title = CandidateValidation.title!(title, fallback: "Reflection")
      context_text = CandidateValidation.optional_string!(
        "user_context", user_context, max: CandidateValidation::CAPTURE_CONTEXT_MAX_LENGTH
      )
      context_text = nil if context_text&.strip&.empty?
      represented = CandidateValidation.represented_date!(represented_date)
      time = CandidateValidation.generation_time!(generated_at)
      input = {
        "confirmed_user_authored" => true,
        "represented_date" => represented,
        "title" => normalized_title,
        "user_context" => context_text,
        "user_text" => text
      }

      idempotent_write(
        vault_root: vault_root,
        request_id: request_id,
        operation: OP_CAPTURE,
        input: input,
        time: time,
        directory: "00_raw_artifacts/text",
        basename: "artifact_#{time.fetch(:date)}_#{slug(normalized_title, fallback: "reflection")}",
        lock_timeout: lock_timeout,
        before_stage: before_stage,
        after_stage: after_stage,
        after_finalize: after_finalize
      ) do |_context, allocation, digest|
        source = {
          "type" => "text",
          "path" => allocation.fetch(:relative_path),
          "extraction_method" => "manual",
          "authorship" => "user",
          "capture_channel" => "mcp"
        }
        source["represented_date"] = represented unless represented.nil?
        frontmatter = common_frontmatter(
          id: allocation.fetch(:id),
          type: "artifact",
          review_status: "needs_review",
          date: time.fetch(:date),
          source: source,
          interpretation_level: "none",
          request_id: request_id,
          operation: OP_CAPTURE,
          digest: digest,
          generated_at: time.fetch(:iso8601),
          tags: []
        )
        bytes = CandidateRenderer.render_user_text(
          frontmatter: frontmatter,
          title: normalized_title,
          user_context: context_text,
          user_text: text,
          represented_date: represented
        )
        result = base_result(allocation, frontmatter, digest).merge(
          "lifecycle_class" => "source_evidence",
          "replayed" => false,
          "requires_review" => true,
          "interpretation_created" => false
        )
        { bytes: bytes, result: result }
      end
    end

    def propose_note(vault_root:, request_id:, candidate_type:, title:, basis:, primary_evidence_id:, evidence_ids:,
                     source_backed_facts:, confidence:, generated_at:, counterevidence_ids: [], user_context: [],
                     tentative_hypotheses: [], tags: [], lock_timeout: nil, before_stage: nil, after_stage: nil,
                     after_finalize: nil)
      request_id = Idempotency.validate_request_id!(request_id)
      note_type = CandidateValidation.candidate_type!(candidate_type)
      normalized_title = CandidateValidation.title!(title)
      normalized_basis = CandidateValidation.basis!(basis)
      primary_id, evidence, counterevidence = normalized_reference_inputs(
        primary_evidence_id, evidence_ids, counterevidence_ids
      )
      facts = CandidateValidation.string_array!(
        source_backed_facts,
        name: "source_backed_facts",
        min: CandidateValidation::FACT_MIN_COUNT,
        max: CandidateValidation::FACT_MAX_COUNT,
        item_max: CandidateValidation::FACT_MAX_LENGTH
      )
      context_items = CandidateValidation.string_array!(
        user_context,
        name: "user_context",
        min: 0,
        max: CandidateValidation::NOTE_CONTEXT_MAX_COUNT,
        item_max: CandidateValidation::NOTE_CONTEXT_MAX_LENGTH
      )
      hypotheses = CandidateValidation.string_array!(
        tentative_hypotheses,
        name: "tentative_hypotheses",
        min: 0,
        max: CandidateValidation::HYPOTHESIS_MAX_COUNT,
        item_max: CandidateValidation::HYPOTHESIS_MAX_LENGTH
      )
      invalid!("agent_inferred basis requires a tentative hypothesis") if normalized_basis == "agent_inferred" && hypotheses.empty?
      normalized_confidence = CandidateValidation.confidence!(confidence)
      normalized_tags = CandidateValidation.tags!(tags)
      time = CandidateValidation.generation_time!(generated_at)
      input = {
        "basis" => normalized_basis,
        "candidate_type" => note_type,
        "confidence" => normalized_confidence,
        "counterevidence_ids" => counterevidence,
        "evidence_ids" => evidence,
        "primary_evidence_id" => primary_id,
        "source_backed_facts" => facts,
        "tags" => normalized_tags,
        "tentative_hypotheses" => hypotheses,
        "title" => normalized_title,
        "user_context" => context_items
      }

      idempotent_write(
        vault_root: vault_root,
        request_id: request_id,
        operation: OP_NOTE,
        input: input,
        time: time,
        directory: INBOX_DIRS.fetch("note"),
        basename: "note_#{time.fetch(:date)}_#{slug(normalized_title, fallback: "note")}",
        lock_timeout: lock_timeout,
        before_stage: before_stage,
        after_stage: after_stage,
        after_finalize: after_finalize
      ) do |context, allocation, digest|
        refs, counter_refs, primary = resolve_evidence!(context, primary_id, evidence, counterevidence)
        interpretation = normalized_basis == "agent_inferred" || !hypotheses.empty? ? "medium" : "low"
        frontmatter = candidate_frontmatter(
          allocation: allocation,
          type: "note",
          date: time.fetch(:date),
          source: source_for(primary),
          basis: normalized_basis,
          interpretation_level: interpretation,
          evidence: refs,
          counterevidence: counter_refs,
          confidence: normalized_confidence,
          tags: normalized_tags,
          request_id: request_id,
          operation: OP_NOTE,
          digest: digest,
          generated_at: time.fetch(:iso8601)
        )
        frontmatter["candidate_type"] = note_type
        bytes = CandidateRenderer.render_note(
          frontmatter: frontmatter,
          title: normalized_title,
          facts: facts,
          user_context: context_items,
          hypotheses: hypotheses
        )
        result = base_result(allocation, frontmatter, digest).merge(
          "candidate_type" => note_type,
          "evidence_ids" => evidence,
          "counterevidence_ids" => counterevidence,
          "lifecycle_class" => "agent_candidate",
          "replayed" => false,
          "requires_review" => true
        )
        { bytes: bytes, result: result }
      end
    end

    def propose_claim(vault_root:, request_id:, title:, statement:, basis:, primary_evidence_id:, evidence_ids:,
                      confidence:, generated_at:, counterevidence_ids: [], boundaries: [], tags: [], lock_timeout: nil,
                      before_stage: nil, after_stage: nil, after_finalize: nil)
      request_id = Idempotency.validate_request_id!(request_id)
      normalized_title = CandidateValidation.title!(title)
      normalized_statement = CandidateValidation.required_string!(
        "statement", statement, max: CandidateValidation::STATEMENT_MAX_LENGTH
      )
      normalized_basis = CandidateValidation.basis!(basis)
      primary_id, evidence, counterevidence = normalized_reference_inputs(
        primary_evidence_id, evidence_ids, counterevidence_ids
      )
      normalized_boundaries = CandidateValidation.string_array!(
        boundaries,
        name: "boundaries",
        min: 0,
        max: CandidateValidation::BOUNDARY_MAX_COUNT,
        item_max: CandidateValidation::BOUNDARY_MAX_LENGTH
      )
      normalized_confidence = CandidateValidation.confidence!(confidence)
      normalized_tags = CandidateValidation.tags!(tags)
      time = CandidateValidation.generation_time!(generated_at)
      input = {
        "basis" => normalized_basis,
        "boundaries" => normalized_boundaries,
        "confidence" => normalized_confidence,
        "counterevidence_ids" => counterevidence,
        "evidence_ids" => evidence,
        "primary_evidence_id" => primary_id,
        "statement" => normalized_statement,
        "tags" => normalized_tags,
        "title" => normalized_title
      }

      idempotent_write(
        vault_root: vault_root,
        request_id: request_id,
        operation: OP_CLAIM,
        input: input,
        time: time,
        directory: INBOX_DIRS.fetch("claim"),
        basename: "claim_#{time.fetch(:date)}_#{slug(normalized_title, fallback: "claim")}",
        lock_timeout: lock_timeout,
        before_stage: before_stage,
        after_stage: after_stage,
        after_finalize: after_finalize
      ) do |context, allocation, digest|
        refs, counter_refs, primary = resolve_evidence!(context, primary_id, evidence, counterevidence)
        frontmatter = candidate_frontmatter(
          allocation: allocation,
          type: "claim",
          date: time.fetch(:date),
          source: source_for(primary),
          basis: normalized_basis,
          interpretation_level: normalized_basis == "agent_inferred" ? "medium" : "low",
          evidence: refs,
          counterevidence: counter_refs,
          confidence: normalized_confidence,
          tags: normalized_tags,
          request_id: request_id,
          operation: OP_CLAIM,
          digest: digest,
          generated_at: time.fetch(:iso8601)
        )
        bytes = CandidateRenderer.render_claim(
          frontmatter: frontmatter,
          title: normalized_title,
          statement: normalized_statement,
          evidence: refs,
          counterevidence: counter_refs,
          boundaries: normalized_boundaries
        )
        result = base_result(allocation, frontmatter, digest).merge(
          "evidence_ids" => evidence,
          "counterevidence_ids" => counterevidence,
          "lifecycle_class" => "agent_candidate",
          "replayed" => false,
          "requires_review" => true
        )
        { bytes: bytes, result: result }
      end
    end

    def propose_relationship(vault_root:, request_id:, from_id:, to_id:, relationship_type:, statement:, basis:,
                             primary_evidence_id:, evidence_ids:, confidence:, generated_at:, counterevidence_ids: [],
                             confidence_rationale: nil, tags: [], lock_timeout: nil, before_stage: nil, after_stage: nil,
                             after_finalize: nil)
      request_id = Idempotency.validate_request_id!(request_id)
      normalized_from = record_id!("from_id", from_id)
      normalized_to = record_id!("to_id", to_id)
      invalid!("relationship endpoints must differ") if normalized_from == normalized_to
      normalized_type = CandidateValidation.relationship_type!(relationship_type)
      normalized_statement = CandidateValidation.required_string!(
        "statement", statement, max: CandidateValidation::STATEMENT_MAX_LENGTH
      )
      normalized_basis = CandidateValidation.basis!(basis)
      primary_id, evidence, counterevidence = normalized_reference_inputs(
        primary_evidence_id, evidence_ids, counterevidence_ids
      )
      rationale = CandidateValidation.optional_string!(
        "confidence_rationale", confidence_rationale, max: CandidateValidation::CONFIDENCE_RATIONALE_MAX_LENGTH
      )
      rationale = nil if rationale&.strip&.empty?
      normalized_confidence = CandidateValidation.confidence!(confidence)
      normalized_tags = CandidateValidation.tags!(tags)
      time = CandidateValidation.generation_time!(generated_at)
      input = {
        "basis" => normalized_basis,
        "confidence" => normalized_confidence,
        "confidence_rationale" => rationale,
        "counterevidence_ids" => counterevidence,
        "evidence_ids" => evidence,
        "from_id" => normalized_from,
        "primary_evidence_id" => primary_id,
        "relationship_type" => normalized_type,
        "statement" => normalized_statement,
        "tags" => normalized_tags,
        "to_id" => normalized_to
      }
      relation_slug = slug("#{normalized_from}-#{normalized_type}-#{normalized_to}", fallback: "relationship")

      idempotent_write(
        vault_root: vault_root,
        request_id: request_id,
        operation: OP_RELATIONSHIP,
        input: input,
        time: time,
        directory: INBOX_DIRS.fetch("relationship"),
        basename: "edge_#{time.fetch(:date)}_#{relation_slug}",
        lock_timeout: lock_timeout,
        before_stage: before_stage,
        after_stage: after_stage,
        after_finalize: after_finalize
      ) do |context, allocation, digest|
        refs, counter_refs, primary = resolve_evidence!(context, primary_id, evidence, counterevidence)
        from = resolve_endpoint!(context, normalized_from)
        to = resolve_endpoint!(context, normalized_to)
        frontmatter = candidate_frontmatter(
          allocation: allocation,
          type: "relationship",
          date: time.fetch(:date),
          source: source_for(primary),
          basis: normalized_basis,
          interpretation_level: normalized_basis == "agent_inferred" ? "medium" : "low",
          evidence: refs,
          counterevidence: counter_refs,
          confidence: normalized_confidence,
          tags: normalized_tags,
          request_id: request_id,
          operation: OP_RELATIONSHIP,
          digest: digest,
          generated_at: time.fetch(:iso8601)
        )
        frontmatter["relationship"] = {
          "from" => normalized_from,
          "to" => normalized_to,
          "type" => normalized_type
        }
        bytes = CandidateRenderer.render_relationship(
          frontmatter: frontmatter,
          from_id: normalized_from,
          to_id: normalized_to,
          statement: normalized_statement,
          evidence: refs,
          confidence_rationale: rationale
        )
        endpoint_result = endpoints_result(from, to)
        result = base_result(allocation, frontmatter, digest).merge(
          "relationship_type" => normalized_type,
          "endpoints" => endpoint_result,
          "approval_ready" => endpoint_result.values.all? { |endpoint| endpoint.fetch("approval_ready") },
          "evidence_ids" => evidence,
          "counterevidence_ids" => counterevidence,
          "lifecycle_class" => "agent_candidate",
          "replayed" => false,
          "requires_review" => true
        )
        { bytes: bytes, result: result }
      end
    end

    def idempotent_write(vault_root:, request_id:, operation:, input:, time:, directory:, basename:, lock_timeout:,
                         before_stage:, after_stage:, after_finalize:)
      root = PathGuard.validate_vault_root(vault_root)
      digest = Idempotency.canonical_digest(operation: operation, input: input)
      timeout = normalize_lock_timeout(lock_timeout)
      VaultLock.new(vault_root: root, timeout: timeout).with_exclusive do
        context = RecordIndex.scan!(vault_root: root)
        reject_duplicate_record_ids!(context)
        replay = Idempotency.find_replay!(
          context: context,
          request_id: request_id,
          operation: operation,
          input_sha256: digest
        )
        return replay_result(operation, replay, context, digest) unless replay.nil?

        allocation = CollisionAllocator.next_available_path(
          vault_root: root,
          directory: directory,
          basename: basename,
          reserved_ids: context.records_by_id.keys
        )
        rendered = yield(context, allocation, digest)
        validate_rendered!(rendered.fetch(:bytes), allocation)
        before_stage.call if before_stage
        staged = AtomicWriter.stage(
          vault_root: root,
          path: allocation.fetch(:relative_path),
          bytes: rendered.fetch(:bytes),
          validate: lambda do |temp_path|
            frontmatter, = Nous.parse_markdown(temp_path, error_path: allocation.fetch(:relative_path))
            invalid!("rendered record id is invalid") unless frontmatter["id"] == allocation.fetch(:id)
          end
        )
        begin
          after_stage.call if after_stage
          staged.finalize
          after_finalize.call if after_finalize
        ensure
          staged.cleanup
        end
        rendered.fetch(:result)
      end
    end
    private_class_method :idempotent_write

    def normalized_reference_inputs(primary_evidence_id, evidence_ids, counterevidence_ids)
      primary = record_id!("primary_evidence_id", primary_evidence_id)
      evidence = CandidateValidation.string_array!(
        evidence_ids,
        name: "evidence_ids",
        min: CandidateValidation::EVIDENCE_MIN_COUNT,
        max: CandidateValidation::EVIDENCE_MAX_COUNT,
        item_max: ID_MAX_LENGTH
      )
      counterevidence = CandidateValidation.string_array!(
        counterevidence_ids,
        name: "counterevidence_ids",
        min: 0,
        max: CandidateValidation::COUNTEREVIDENCE_MAX_COUNT,
        item_max: ID_MAX_LENGTH
      )
      invalid!("primary_evidence_id must appear in evidence_ids") unless evidence.include?(primary)
      invalid!("evidence_ids and counterevidence_ids must not overlap") unless (evidence & counterevidence).empty?

      [primary, evidence, counterevidence]
    end
    private_class_method :normalized_reference_inputs

    def resolve_evidence!(context, primary_id, evidence_ids, counterevidence_ids)
      resolved = (evidence_ids + counterevidence_ids).each_with_object({}) do |id, records|
        record = context.unique_record!(id)
        unless eligible_evidence?(record)
          raise Error.new("record is not eligible evidence", code: "NOUS_INVALID_EVIDENCE", details: { id: id })
        end

        records[id] = record
      end
      references = evidence_ids.map { |id| evidence_reference(resolved.fetch(id)) }
      counter_references = counterevidence_ids.map { |id| evidence_reference(resolved.fetch(id)) }
      [references, counter_references, resolved.fetch(primary_id)]
    end
    private_class_method :resolve_evidence!

    def eligible_evidence?(record)
      return true if record.kind == "artifact" && record.lifecycle == "source_evidence"
      return true if record.scope == "reviewed" && record.lifecycle == "human_reviewed"
      return true if record.kind == "claim" && record.scope == "canonical" && record.lifecycle == "canonical"

      false
    end
    private_class_method :eligible_evidence?

    def resolve_endpoint!(context, id)
      record = context.unique_record!(id)
      allowed = if record.lifecycle == "agent_candidate"
                  %w[note claim].include?(record.kind)
                elsif record.lifecycle == "human_reviewed"
                  record.scope == "reviewed"
                elsif record.lifecycle == "canonical"
                  record.kind == "claim" && record.scope == "canonical"
                else
                  false
                end
      unless allowed
        raise Error.new("record is not an eligible relationship endpoint", code: "NOUS_INVALID_ENDPOINT", details: { id: id })
      end

      record
    end
    private_class_method :resolve_endpoint!

    def endpoint_result(record)
      {
        "id" => record.id,
        "lifecycle_class" => record.lifecycle,
        "approval_ready" => %w[human_reviewed canonical].include?(record.lifecycle)
      }
    end
    private_class_method :endpoint_result

    def endpoints_result(from, to)
      { "from" => endpoint_result(from), "to" => endpoint_result(to) }
    end
    private_class_method :endpoints_result

    def replay_result(operation, record, context, digest)
      frontmatter = record.frontmatter
      result = {
        "record_id" => record.id,
        "record_type" => frontmatter["type"].to_s,
        "relative_path" => record.relative_path,
        "lifecycle_class" => record.lifecycle,
        "input_sha256" => digest,
        "replayed" => true,
        "requires_review" => record.lifecycle == "agent_candidate"
      }
      case operation
      when OP_CAPTURE
        result["requires_review"] = record.lifecycle == "source_evidence"
        result["interpretation_created"] = false
      when OP_NOTE
        result["candidate_type"] = frontmatter["candidate_type"] || frontmatter["type"]
        result["evidence_ids"] = reference_ids(frontmatter["evidence"])
        result["counterevidence_ids"] = reference_ids(frontmatter["counterevidence"])
      when OP_CLAIM
        result["evidence_ids"] = reference_ids(frontmatter["evidence"])
        result["counterevidence_ids"] = reference_ids(frontmatter["counterevidence"])
      when OP_RELATIONSHIP
        relationship = frontmatter["relationship"]
        malformed!("relationship generation record is malformed") unless relationship.is_a?(Hash)
        from = context.unique_record!(relationship["from"])
        to = context.unique_record!(relationship["to"])
        endpoints = endpoints_result(from, to)
        result["relationship_type"] = relationship["type"]
        result["endpoints"] = endpoints
        result["approval_ready"] = endpoints.values.all? { |endpoint| endpoint.fetch("approval_ready") }
        result["evidence_ids"] = reference_ids(frontmatter["evidence"])
        result["counterevidence_ids"] = reference_ids(frontmatter["counterevidence"])
      end
      result
    end
    private_class_method :replay_result

    def common_frontmatter(id:, type:, review_status:, date:, source:, interpretation_level:, request_id:, operation:,
                           digest:, generated_at:, tags:, confidence: nil, basis: nil, evidence: nil,
                           counterevidence: nil)
      frontmatter = {
        "id" => id,
        "type" => type,
        "schema_version" => SCHEMA_VERSION,
        "status" => "draft",
        "review_status" => review_status,
        "created" => date,
        "updated" => date,
        "source" => source,
        "interpretation_level" => interpretation_level,
        "generation" => {
          "interface" => "mcp",
          "operation" => operation,
          "request_id" => request_id,
          "input_sha256" => digest,
          "generated_at" => generated_at
        },
        "tags" => tags
      }
      frontmatter["basis"] = basis unless basis.nil?
      frontmatter["confidence"] = confidence unless confidence.nil?
      frontmatter["evidence"] = evidence unless evidence.nil?
      frontmatter["counterevidence"] = counterevidence unless counterevidence.nil?
      frontmatter
    end
    private_class_method :common_frontmatter

    def candidate_frontmatter(allocation:, type:, date:, source:, basis:, interpretation_level:, evidence:,
                              counterevidence:, confidence:, tags:, request_id:, operation:, digest:, generated_at:)
      common_frontmatter(
        id: allocation.fetch(:id),
        type: type,
        review_status: "agent_generated",
        date: date,
        source: source,
        interpretation_level: interpretation_level,
        request_id: request_id,
        operation: operation,
        digest: digest,
        generated_at: generated_at,
        tags: tags,
        confidence: confidence,
        basis: basis,
        evidence: evidence,
        counterevidence: counterevidence
      ).merge("related" => [])
    end
    private_class_method :candidate_frontmatter

    def generation(frontmatter)
      value = frontmatter["generation"]
      malformed!("generation metadata is missing") unless value.is_a?(Hash)

      value
    end
    private_class_method :generation

    def base_result(allocation, frontmatter, digest)
      {
        "record_id" => allocation.fetch(:id),
        "record_type" => frontmatter.fetch("type"),
        "relative_path" => allocation.fetch(:relative_path),
        "input_sha256" => digest
      }
    end
    private_class_method :base_result

    def evidence_reference(record)
      { "id" => record.id, "path" => record.relative_path }
    end
    private_class_method :evidence_reference

    def source_for(record)
      source_type = if record.kind == "artifact"
                      source = record.frontmatter["source"]
                      source.is_a?(Hash) ? source["type"].to_s : "note"
                    else
                      "note"
                    end
      source_type = "note" unless %w[text writing image project note manual].include?(source_type)
      {
        "type" => source_type,
        "path" => record.relative_path,
        "extraction_method" => "archivist_agent"
      }
    end
    private_class_method :source_for

    def reference_ids(value)
      return [] unless value.is_a?(Array)

      value.filter_map { |entry| entry["id"].to_s if entry.is_a?(Hash) && !entry["id"].to_s.empty? }
    end
    private_class_method :reference_ids

    def record_id!(name, value)
      CandidateValidation.required_string!(name, value, max: ID_MAX_LENGTH)
    end
    private_class_method :record_id!

    def normalize_lock_timeout(value)
      return nil if value.nil?

      timeout = Float(value)
      invalid!("lock timeout must be positive") unless timeout.finite? && timeout.positive?
      timeout
    rescue ArgumentError, TypeError
      invalid!("lock timeout must be numeric")
    end
    private_class_method :normalize_lock_timeout

    def reject_duplicate_record_ids!(context)
      return if context.duplicates.empty?

      id, paths = context.duplicates.sort.first
      raise Error.new("duplicate record id", code: "NOUS_DUPLICATE_ID", details: { id: id, count: paths.length })
    end
    private_class_method :reject_duplicate_record_ids!

    def validate_rendered!(bytes, allocation)
      match = bytes.match(/\A---\n(.*?)\n---\n/m)
      malformed!("rendered record is missing frontmatter") if match.nil?
      frontmatter = Psych.safe_load(match[1], aliases: false)
      malformed!("rendered record frontmatter is invalid") unless frontmatter.is_a?(Hash)
      malformed!("rendered record id is invalid") unless frontmatter["id"] == allocation.fetch(:id)
      generation(frontmatter)
    rescue Psych::Exception
      malformed!("rendered record frontmatter is invalid")
    end
    private_class_method :validate_rendered!

    def slug(value, fallback:)
      slug = value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
      slug = fallback if slug.empty?
      slug[0, 80].gsub(/-+\z/, "").then { |bounded| bounded.empty? ? fallback : bounded }
    end
    private_class_method :slug

    def malformed!(message)
      raise Error.new(message, code: "NOUS_PARSE_FAILED")
    end
    private_class_method :malformed!

    def invalid!(message)
      raise Error.new(message, code: "NOUS_INVALID_INPUT")
    end
    private_class_method :invalid!
  end

  def self.capture_user_text(vault_root:, request_id:, generated_at:, confirmed_user_authored:, user_text:, title: nil,
                             user_context: nil, represented_date: nil, lock_timeout: nil, before_stage: nil,
                             after_stage: nil, after_finalize: nil)
    CandidateWrites.capture_user_text(
      vault_root: vault_root,
      request_id: request_id,
      generated_at: generated_at,
      confirmed_user_authored: confirmed_user_authored,
      user_text: user_text,
      title: title,
      user_context: user_context,
      represented_date: represented_date,
      lock_timeout: lock_timeout,
      before_stage: before_stage,
      after_stage: after_stage,
      after_finalize: after_finalize
    )
  end

  def self.propose_note(vault_root:, request_id:, generated_at:, candidate_type:, title:, basis:,
                        primary_evidence_id:, evidence_ids:, source_backed_facts:, confidence:,
                        counterevidence_ids: [], user_context: [], tentative_hypotheses: [], tags: [],
                        lock_timeout: nil, before_stage: nil, after_stage: nil, after_finalize: nil)
    CandidateWrites.propose_note(
      vault_root: vault_root,
      request_id: request_id,
      generated_at: generated_at,
      candidate_type: candidate_type,
      title: title,
      basis: basis,
      primary_evidence_id: primary_evidence_id,
      evidence_ids: evidence_ids,
      counterevidence_ids: counterevidence_ids,
      source_backed_facts: source_backed_facts,
      user_context: user_context,
      tentative_hypotheses: tentative_hypotheses,
      confidence: confidence,
      tags: tags,
      lock_timeout: lock_timeout,
      before_stage: before_stage,
      after_stage: after_stage,
      after_finalize: after_finalize
    )
  end

  def self.propose_claim(vault_root:, request_id:, generated_at:, title:, statement:, basis:, primary_evidence_id:,
                         evidence_ids:, confidence:, counterevidence_ids: [], boundaries: [], tags: [],
                         lock_timeout: nil, before_stage: nil, after_stage: nil, after_finalize: nil)
    CandidateWrites.propose_claim(
      vault_root: vault_root,
      request_id: request_id,
      generated_at: generated_at,
      title: title,
      statement: statement,
      basis: basis,
      primary_evidence_id: primary_evidence_id,
      evidence_ids: evidence_ids,
      counterevidence_ids: counterevidence_ids,
      boundaries: boundaries,
      confidence: confidence,
      tags: tags,
      lock_timeout: lock_timeout,
      before_stage: before_stage,
      after_stage: after_stage,
      after_finalize: after_finalize
    )
  end

  def self.propose_relationship(vault_root:, request_id:, generated_at:, from_id:, to_id:, relationship_type:,
                                statement:, basis:, primary_evidence_id:, evidence_ids:, confidence:,
                                counterevidence_ids: [], confidence_rationale: nil, tags: [], lock_timeout: nil,
                                before_stage: nil, after_stage: nil, after_finalize: nil)
    CandidateWrites.propose_relationship(
      vault_root: vault_root,
      request_id: request_id,
      generated_at: generated_at,
      from_id: from_id,
      to_id: to_id,
      relationship_type: relationship_type,
      statement: statement,
      basis: basis,
      primary_evidence_id: primary_evidence_id,
      evidence_ids: evidence_ids,
      counterevidence_ids: counterevidence_ids,
      confidence: confidence,
      confidence_rationale: confidence_rationale,
      tags: tags,
      lock_timeout: lock_timeout,
      before_stage: before_stage,
      after_stage: after_stage,
      after_finalize: after_finalize
    )
  end
end
