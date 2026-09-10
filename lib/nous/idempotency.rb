# frozen_string_literal: true

require "digest"
require "json"
require "time"

module Nous
  module Idempotency
    OPERATIONS = %w[
      nous_capture_user_text
      nous_propose_note
      nous_propose_claim
      nous_propose_relationship
    ].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    module_function

    def validate_request_id!(value)
      CandidateValidation.request_id!(value)
    end

    def canonical_digest(operation:, input:)
      operation_name = validate_operation!(operation)
      canonical = canonical_value(input)

      Digest::SHA256.hexdigest(JSON.generate({ "input" => canonical, "operation" => operation_name }))
    rescue JSON::GeneratorError
      invalid!("idempotency input is invalid")
    end

    def find_replay!(context:, request_id:, operation:, input_sha256:)
      request_key = validate_request_id!(request_id)
      operation_name = validate_operation!(operation)
      digest = validate_digest!(input_sha256)
      records = context.respond_to?(:records) ? context.records : nil
      invalid!("record index context is invalid") unless records.is_a?(Array)

      matches = records.select do |record|
        generation = generation_for(record)
        generation.is_a?(Hash) && metadata_value(generation, "request_id") == request_key
      end

      if matches.length > 1
        raise Nous::Error.new(
          "duplicate generation request_id metadata",
          code: "NOUS_IDEMPOTENCY_CONFLICT",
          details: { request_id: request_key, count: matches.length }
        )
      end
      return nil if matches.empty?

      record = matches.first
      generation = generation_for(record)
      validate_matching_generation!(generation, request_key)

      stored_operation = metadata_value(generation, "operation")
      stored_digest = metadata_value(generation, "input_sha256")
      unless stored_operation == operation_name && stored_digest == digest
        raise Nous::Error.new(
          "request_id was already used with different input",
          code: "NOUS_IDEMPOTENCY_CONFLICT",
          details: { request_id: request_key }
        )
      end

      record
    end

    def canonical_value(value)
      case value
      when Hash
        entries = value.each_with_object({}) do |(key, item), normalized|
          unless key.is_a?(String) || key.is_a?(Symbol)
            invalid!("idempotency object keys must be strings")
          end

          string_key = key.to_s
          invalid!("idempotency object has duplicate keys") if normalized.key?(string_key)

          normalized[string_key] = canonical_value(item)
        end
        entries.keys.sort.each_with_object({}) { |key, sorted| sorted[key] = entries.fetch(key) }
      when Array
        value.map { |item| canonical_value(item) }
      when String
        invalid!("idempotency input must be valid UTF-8") unless value.valid_encoding?

        value.encode(Encoding::UTF_8)
      when Integer, TrueClass, FalseClass, NilClass
        value
      when Float
        invalid!("idempotency numbers must be finite") unless value.finite?

        value
      else
        invalid!("idempotency input contains an unsupported value")
      end
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      invalid!("idempotency input must be valid UTF-8")
    end
    private_class_method :canonical_value

    def generation_for(record)
      frontmatter = record.respond_to?(:frontmatter) ? record.frontmatter : nil
      return nil unless frontmatter.is_a?(Hash)

      metadata_value(frontmatter, "generation")
    end
    private_class_method :generation_for

    def validate_matching_generation!(generation, request_id)
      malformed_generation! unless generation.is_a?(Hash)
      malformed_generation! unless metadata_value(generation, "interface") == "mcp"
      malformed_generation! unless metadata_value(generation, "request_id") == request_id

      stored_operation = metadata_value(generation, "operation")
      malformed_generation! unless OPERATIONS.include?(stored_operation)

      stored_digest = metadata_value(generation, "input_sha256")
      malformed_generation! unless stored_digest.is_a?(String) && DIGEST_PATTERN.match?(stored_digest)

      generated_at = metadata_value(generation, "generated_at")
      malformed_generation! unless valid_utc_timestamp?(generated_at)
    end
    private_class_method :validate_matching_generation!

    def valid_utc_timestamp?(value)
      return false unless value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/.match?(value)

      Time.iso8601(value).utc.iso8601 == value
    rescue ArgumentError
      false
    end
    private_class_method :valid_utc_timestamp?

    def metadata_value(metadata, key)
      if metadata.key?(key)
        metadata[key]
      elsif metadata.key?(key.to_sym)
        metadata[key.to_sym]
      end
    end
    private_class_method :metadata_value

    def validate_operation!(value)
      unless value.is_a?(String) && OPERATIONS.include?(value)
        invalid!("unsupported operation")
      end

      value
    end
    private_class_method :validate_operation!

    def validate_digest!(value)
      unless value.is_a?(String) && DIGEST_PATTERN.match?(value)
        invalid!("input_sha256 must be 64 lowercase hexadecimal characters")
      end

      value
    end
    private_class_method :validate_digest!

    def malformed_generation!
      raise Nous::Error.new("matching generation metadata is malformed", code: "NOUS_PARSE_FAILED")
    end
    private_class_method :malformed_generation!

    def invalid!(message)
      raise Nous::Error.new(message, code: "NOUS_INVALID_INPUT")
    end
    private_class_method :invalid!
  end
end
