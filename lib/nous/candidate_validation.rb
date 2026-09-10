# frozen_string_literal: true

require "date"
require "time"

module Nous
  module CandidateValidation
    REQUEST_ID_MAX_LENGTH = 128
    REQUEST_ID_PATTERN = /\A[A-Za-z0-9._:-]{1,128}\z/
    DISALLOWED_CONTROL_PATTERN = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/
    CAPTURE_TEXT_MAX_LENGTH = 1024 * 1024
    CAPTURE_CONTEXT_MAX_LENGTH = 2_000
    TITLE_MAX_LENGTH = 120
    FACT_MIN_COUNT = 1
    FACT_MAX_COUNT = 10
    FACT_MAX_LENGTH = 500
    NOTE_CONTEXT_MAX_COUNT = 5
    NOTE_CONTEXT_MAX_LENGTH = 1_000
    HYPOTHESIS_MAX_COUNT = 5
    HYPOTHESIS_MAX_LENGTH = 500
    STATEMENT_MAX_LENGTH = 1_000
    CONFIDENCE_RATIONALE_MAX_LENGTH = 1_000
    BOUNDARY_MAX_COUNT = 10
    BOUNDARY_MAX_LENGTH = 500
    EVIDENCE_MIN_COUNT = 1
    EVIDENCE_MAX_COUNT = 20
    COUNTEREVIDENCE_MAX_COUNT = 20
    CANDIDATE_TYPES = %w[
      memory
      value
      belief
      project
      pattern
      decision
      person
      question
      contradiction
    ].freeze
    BASES = %w[user_asserted extractive agent_inferred].freeze
    TAG_MAX_COUNT = 20
    TAG_MAX_LENGTH = 64

    module_function

    def request_id!(value)
      unless value.is_a?(String) && value.valid_encoding? && REQUEST_ID_PATTERN.match?(value)
        invalid!("request_id is invalid")
      end

      value
    end

    def generation_time!(value)
      time = case value
             when Time
               value
             when DateTime
               value.to_time
             when String
               unless /(?:Z|[+-]\d{2}:\d{2})\z/i.match?(value)
                 invalid!("generated_at must include an ISO-8601 timezone")
               end
               Time.iso8601(value)
             else
               invalid!("generated_at must be an ISO-8601 timestamp")
             end
      utc = time.utc
      { time: utc, iso8601: utc.iso8601, date: utc.to_date.iso8601 }
    rescue ArgumentError
      invalid!("generated_at must be an ISO-8601 timestamp")
    end

    def normalize_line_endings(value)
      return value unless value.is_a?(String)

      value.gsub("\r\n", "\n").gsub("\r", "\n")
    end

    def required_string!(name, value, max:)
      utf8_string!(value, name: name, min: 1, max: max, allow_blank: false)
    end

    def optional_string!(name, value, max:)
      return nil if value.nil?

      utf8_string!(value, name: name, min: 0, max: max, allow_blank: true)
    end

    def utf8_string!(value, name:, min:, max:, allow_blank:)
      minimum = nonnegative_bound!(min)
      maximum = nonnegative_bound!(max)
      invalid!("#{name} bounds are invalid") if minimum > maximum

      string = validated_string!(name, value)
      invalid!("#{name} is required") if !allow_blank && string.strip.empty?
      unless string.length.between?(minimum, maximum)
        invalid!("#{name} must contain between #{minimum} and #{maximum} characters")
      end

      string
    end

    def title!(value, fallback: nil)
      source = value.nil? || (value.is_a?(String) && value.strip.empty?) ? fallback : value
      title = validated_string!("title", source)
      title = title.gsub(/[ \t]*(?:\n|\u2028|\u2029)+[ \t]*/, " ").strip
      invalid!("title is required") if title.empty?
      invalid!("title is too long") if title.length > TITLE_MAX_LENGTH

      title
    end

    def string_array!(value, name:, min:, max:, item_max:)
      minimum = nonnegative_bound!(min)
      maximum = nonnegative_bound!(max)
      item_limit = positive_bound!(item_max)
      invalid!("#{name} bounds are invalid") if minimum > maximum
      invalid!("#{name} must be an array") unless value.is_a?(Array)
      unless value.length.between?(minimum, maximum)
        invalid!("#{name} must contain between #{minimum} and #{maximum} items")
      end

      strings = value.map { |item| required_string!(name, item, max: item_limit) }
      invalid!("#{name} must not contain duplicates") unless strings.uniq.length == strings.length

      strings
    end

    def confidence!(value)
      confidence = Float(value)
      unless confidence.finite? && confidence.between?(0.0, 1.0)
        invalid!("confidence must be between 0 and 1")
      end

      confidence
    rescue ArgumentError, TypeError
      invalid!("confidence must be numeric")
    end

    def candidate_type!(value)
      enum_value!("candidate_type", value, CANDIDATE_TYPES)
    end

    def basis!(value)
      enum_value!("basis", value, BASES)
    end

    def tags!(value)
      invalid!("tags must be an array") unless value.is_a?(Array)
      unless value.length <= TAG_MAX_COUNT
        invalid!("tags must contain between 0 and #{TAG_MAX_COUNT} items")
      end

      tags = value.map do |tag|
        string = required_string!("tag", tag, max: TAG_MAX_LENGTH)
        normalized = string.strip.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
        invalid!("tag is invalid") if normalized.empty? || normalized.length > TAG_MAX_LENGTH

        normalized
      end
      invalid!("tags must not contain duplicates") unless tags.uniq.length == tags.length

      tags
    end

    def represented_date!(value)
      return nil if value.nil?

      date = case value
             when DateTime, Time
               invalid!("represented_date must be an ISO-8601 date")
             when Date
               value
             when String
               Date.iso8601(value)
             else
               invalid!("represented_date must be an ISO-8601 date")
             end
      date.iso8601
    rescue Date::Error, ArgumentError
      invalid!("represented_date must be an ISO-8601 date")
    end

    def relationship_type!(value)
      enum_value!("relationship_type", value, Nous::SUPPORTED_RELATIONSHIP_TYPES)
    end

    def validated_string!(name, value)
      invalid!("#{name} must be a string") unless value.is_a?(String)
      invalid!("#{name} must be valid UTF-8") unless value.encoding == Encoding::UTF_8 && value.valid_encoding?

      string = normalize_line_endings(value)
      invalid!("#{name} contains unsupported control characters") if DISALLOWED_CONTROL_PATTERN.match?(string)

      string
    end
    private_class_method :validated_string!

    def enum_value!(name, value, allowed)
      string = required_string!(name, value, max: allowed.map(&:length).max)
      invalid!("unsupported #{name}") unless allowed.include?(string)

      string
    end
    private_class_method :enum_value!

    def positive_bound!(value)
      bound = Integer(value)
      invalid!("validation bound is invalid") unless bound.positive?

      bound
    rescue ArgumentError, TypeError
      invalid!("validation bound is invalid")
    end
    private_class_method :positive_bound!

    def nonnegative_bound!(value)
      bound = Integer(value)
      invalid!("validation bound is invalid") if bound.negative?

      bound
    rescue ArgumentError, TypeError
      invalid!("validation bound is invalid")
    end
    private_class_method :nonnegative_bound!

    def invalid!(message)
      raise Nous::Error.new(message, code: "NOUS_INVALID_INPUT")
    end
    private_class_method :invalid!
  end
end
