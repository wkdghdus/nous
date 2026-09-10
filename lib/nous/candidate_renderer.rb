# frozen_string_literal: true

module Nous
  module CandidateRenderer
    module_function

    def render_user_text(frontmatter:, title:, user_context:, user_text:, represented_date: nil)
      metadata = [
        "- Source type: text",
        "- Date represented: #{represented_date}",
        "- Capture date: #{frontmatter.fetch("created")}",
        "- Authorship: user",
        "- Capture channel: mcp"
      ]
      context = user_context.nil? ? "" : safe_list([user_context])
      body = <<~MARKDOWN
        # #{title}

        ## Source Metadata

        #{metadata.join("\n")}

        ## User-Provided Context

        #{context}

        ## Notes Created From This Artifact

        ## Review Notes

        ## Observed Content
      MARKDOWN
      # `user_text` is the final field so its exact normalized bytes remain the
      # authoritative payload even when it contains Markdown headings.
      render_document(frontmatter, body + user_text)
    end

    def render_note(frontmatter:, title:, facts:, user_context:, hypotheses:)
      body = <<~MARKDOWN
        # #{title}

        ## Source-Backed Facts

        #{safe_list(facts)}

        ## User Context

        #{safe_list(user_context)}

        ## Tentative Hypotheses

        #{safe_list(hypotheses)}

        ## Relationships

        ## Review Notes
      MARKDOWN
      render_document(frontmatter, body)
    end

    def render_claim(frontmatter:, title:, statement:, evidence:, counterevidence:, boundaries:)
      body = <<~MARKDOWN
        # #{title}

        ## Statement

        #{safe_list([statement])}

        ## Evidence

        #{safe_list(reference_lines(evidence))}

        ## Counterevidence

        #{safe_list(reference_lines(counterevidence))}

        ## Boundaries

        #{safe_list(boundaries)}

        ## Review Decision
      MARKDOWN
      render_document(frontmatter, body)
    end

    def render_relationship(frontmatter:, from_id:, to_id:, statement:, evidence:, confidence_rationale:)
      body = <<~MARKDOWN
        # Relationship

        ## Relationship Statement

        #{safe_list([statement])}

        ## From

        #{safe_list([from_id])}

        ## To

        #{safe_list([to_id])}

        ## Evidence

        #{safe_list(reference_lines(evidence))}

        ## Confidence Rationale

        #{safe_list(confidence_rationale.nil? ? [] : [confidence_rationale])}

        ## Review Decision
      MARKDOWN
      render_document(frontmatter, body)
    end

    def render_document(frontmatter, body)
      "---\n#{Nous.yaml_frontmatter(frontmatter)}---\n\n#{body}"
    end

    def safe_list(items)
      Array(items).map do |item|
        lines = item.to_s.split("\n", -1)
        "- #{lines.join("\n  ")}"
      end.join("\n")
    end

    def reference_lines(references)
      Array(references).map { |reference| "#{reference.fetch("id")} (#{reference.fetch("path")})" }
    end
  end
end
