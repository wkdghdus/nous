**Nous**

*Functional Requirements, Non-Functional Requirements, and User Flows*

Version 0.1 - Product specification draft

# 1. Purpose

Nous is a personal self-knowledge pipeline that turns raw life
data and ongoing reflections into a structured, source-backed model of
the user. The first implementation focuses on an Obsidian-based personal
archive, an agent-assisted insertion process, and a reviewable graph of
nodes and relationships. Future modules may include memory chat,
visualization, decision support, persona simulation, and a consent-based
interpersonal graph.

# 2. Product Thesis

- The core product is not a chatbot or visualization. The core product
  is a high-quality, provenance-backed personal data resource.

- Obsidian is the primary capture and review interface for the MVP.

- The agent is a personal archivist. It listens, preserves, structures,
  and links. It should not over-interpret or psychoanalyze by default.

- Raw artifacts remain first-class evidence. Generated notes and graph
  claims should point back to source material.

- The future friend/web-app expansion is important but explicitly out of
  MVP scope.

# 3. Scope

## 3.1 MVP Scope

- Capture text, voice transcripts, writings, photos, screenshots, and
  project artifacts into a raw archive.

- Use an agent to generate Obsidian notes from raw inputs with clear
  provenance and review status.

- Extract candidate nodes and relationships such as values, beliefs,
  memories, patterns, projects, people, decisions, questions, and
  claims.

- Maintain an unreviewed inbox and a canonical reviewed self-model.

- Generate basic outputs such as Nous summaries, graph JSON, and
  review queues.

- Support search and future retrieval by keeping metadata consistent and
  source-backed.

## 3.2 Out of Scope for MVP

- A full social web app where friends create and maintain their own
  profiles.

- Fully autonomous psychological analysis or personality diagnosis.

- A public-facing clone or persona simulator.

- Complex permission management for other people.

- Real-time always-on surveillance capture.

- Medical, legal, or clinical mental-health interpretation.

## 3.3 Future Expansion Scope

The future interpersonal module may let trusted friends or related
people contribute self-authored profiles, relationship context, shared
memories, boundaries, and updates. This is a separate product layer
requiring consent, ownership, deletion, visibility controls, and
conflict handling.

# 4. Actors and Personas

| **Actor**                 | **Role**                                             | **Needs**                                                                                    |
|---------------------------|------------------------------------------------------|----------------------------------------------------------------------------------------------|
| Primary user              | Owner of the self-knowledge vault                    | Capture life data, review agent outputs, build a trusted model of self.                      |
| Archivist agent           | Automated assistant that processes inputs            | Preserve source material, generate notes, suggest links, and create candidate graph updates. |
| Reviewer self             | The same user during curation sessions               | Approve, edit, merge, reject, or deprecate generated notes and claims.                       |
| Future memory assistant   | Query interface over reviewed and source-backed data | Answer questions using citations to notes, claims, and raw artifacts.                        |
| Future friend/contributor | Trusted external person                              | Self-author their own context and control what can connect to the user graph.                |

# 5. Conceptual Data Model

## 5.1 Layers

| **Layer**         | **Description**                                   | **Examples**                                                                |
|-------------------|---------------------------------------------------|-----------------------------------------------------------------------------|
| Raw artifacts     | Untouched or lightly processed evidence layer.    | Audio, transcripts, photos, writings, screenshots, READMEs, project files.  |
| Obsidian notes    | Human-readable reflection and organization layer. | Memory notes, belief notes, project notes, value notes, pattern notes.      |
| Structured graph  | Machine-readable node and relationship layer.     | Nodes, edges, claims, confidence, provenance, review status.                |
| Generated outputs | Views derived from reviewed and unreviewed data.  | Nous summary, timeline, contradiction map, graph JSON, clone context. |

## 5.2 Core Node Types

| **Node type** | **Description**                                                           |
|---------------|---------------------------------------------------------------------------|
| Artifact      | A raw source item or source record.                                       |
| Memory        | A personally meaningful event or remembered episode.                      |
| Value         | A principle, preference, or thing that matters to the user.               |
| Belief        | A statement the user believes, doubts, or is revising.                    |
| Claim         | A machine-readable statement about the user with evidence and confidence. |
| Pattern       | A recurring behavior, theme, reaction, or tendency.                       |
| Project       | A project the user built, explored, abandoned, or imagined.               |
| Decision      | A choice and the reasoning or context around it.                          |
| Person        | A person relevant to the user or a future contributor.                    |
| Question      | An open question the user returns to.                                     |
| Contradiction | A tension between values, beliefs, goals, or behaviors.                   |
| Identity      | A self-concept, role, or identity statement.                              |

## 5.3 Relationship Types

| **Relationship** | **Meaning**                                                           |
|------------------|-----------------------------------------------------------------------|
| evidenced_by     | A node or claim is supported by an artifact or note.                  |
| supports         | One node supports or reinforces another.                              |
| contradicts      | One node conflicts with or complicates another.                       |
| influenced_by    | One node was shaped by another person, memory, project, or event.     |
| expresses        | A project, choice, or artifact expresses a value, belief, or pattern. |
| mentions         | An artifact or note mentions a person, place, project, or theme.      |
| changed_by       | A belief, value, or identity shifted because of an event or evidence. |
| part_of          | A node belongs to a larger period, project, relationship, or theme.   |
| similar_to       | Two nodes share meaning or recurring theme.                           |

# 6. Functional Requirements

## 6.1 Capture and Ingestion

| **ID** | **Priority** | **Requirement**                          | **Acceptance criteria**                                                                                                  |
|--------|--------------|------------------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| FR-001 | Must         | Accept text reflections as direct input. | User can submit a text note and see it stored as a raw artifact plus one or more draft Obsidian notes.                   |
| FR-002 | Must         | Accept voice memo transcripts as input.  | A transcript can be imported and linked back to the original audio file if available.                                    |
| FR-003 | Should       | Accept photo and screenshot artifacts.   | Image artifact notes can capture file path, date, visible content, user-provided context, and suggested links.           |
| FR-004 | Should       | Accept writing archives.                 | Old essays, journals, posts, and documents can be imported as artifacts and summarized without overwriting the original. |
| FR-005 | Should       | Accept project artifacts.                | READMEs, design docs, code summaries, pitch decks, and prototypes can become project artifact notes.                     |
| FR-006 | Must         | Store raw input before interpretation.   | No generated note is created without a source record or source reference.                                                |
| FR-007 | Could        | Support batch imports.                   | A folder of artifacts can be processed into an import queue with generated artifact notes.                               |

## 6.2 Archivist Agent Behavior

| **ID** | **Priority** | **Requirement**                                     | **Acceptance criteria**                                                                                                       |
|--------|--------------|-----------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| FR-008 | Must         | Generate draft notes from raw inputs.               | The agent creates notes in the Agent Inbox rather than directly in the canonical model.                                       |
| FR-009 | Must         | Classify generated notes by type.                   | Each generated note has a type such as memory, value, belief, project, pattern, question, person, or claim.                   |
| FR-010 | Must         | Preserve user wording.                              | Generated notes quote or paraphrase conservatively and avoid replacing the user voice with model voice.                       |
| FR-011 | Must         | Separate facts, user context, and model hypotheses. | Notes contain distinct sections for observed content, user-provided meaning, and tentative interpretations.                   |
| FR-012 | Must         | Attach provenance metadata.                         | Every generated note includes source type, source path or ID, created date, extraction method, confidence, and review status. |
| FR-013 | Must         | Default to low interpretation mode.                 | The agent can classify and link, but psychological interpretation is labelled as hypothesis unless requested.                 |
| FR-014 | Should       | Suggest related existing notes.                     | The agent proposes links to likely related notes without auto-confirming them.                                                |
| FR-015 | Should       | Create candidate claims.                            | The agent can create claims with evidence, counterevidence, confidence, and status.                                           |
| FR-016 | Should       | Ask only minimal clarification questions.           | Clarifying questions are reserved for ambiguous source identity, missing dates, or destructive actions.                       |

## 6.3 Obsidian Vault Management

| **ID** | **Priority** | **Requirement**                                | **Acceptance criteria**                                                                                              |
|--------|--------------|------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| FR-017 | Must         | Write outputs as Obsidian-compatible Markdown. | Generated notes use Markdown and YAML frontmatter that can be read in Obsidian.                                      |
| FR-018 | Must         | Use a predictable folder structure.            | Raw artifacts, Agent Inbox, reviewed notes, canonical model, and generated outputs have separate folders.            |
| FR-019 | Should       | Use stable note IDs.                           | Each note has a stable ID or slug to support graph updates and renaming.                                             |
| FR-020 | Should       | Use templates per note type.                   | Memory, belief, value, project, pattern, claim, and artifact notes follow consistent templates.                      |
| FR-021 | Should       | Create backlinks and wikilinks.                | Suggested relationships are expressed with Obsidian links where practical.                                           |
| FR-022 | Could        | Maintain index notes.                          | Auto-generated index pages list recent artifacts, unreviewed claims, core values, active beliefs, and project nodes. |

## 6.4 Graph and Relationship Generation

| **ID** | **Priority** | **Requirement**                              | **Acceptance criteria**                                                                                           |
|--------|--------------|----------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| FR-023 | Must         | Create candidate graph nodes.                | Each relevant generated note can produce a machine-readable candidate node.                                       |
| FR-024 | Must         | Create candidate relationships.              | The system can propose edges such as evidenced_by, supports, contradicts, influenced_by, expresses, and mentions. |
| FR-025 | Must         | Track confidence per claim and relationship. | Claims and edges have confidence levels or scores and review status.                                              |
| FR-026 | Should       | Export graph data.                           | The graph can be exported as JSON or another documented format.                                                   |
| FR-027 | Should       | Support graph regeneration.                  | The system can rebuild graph outputs from source notes without losing reviewed human decisions.                   |
| FR-028 | Should       | Track contradiction and counterevidence.     | Claims can include counterevidence and conflicting notes.                                                         |
| FR-029 | Could        | Support temporal graph history.              | The system can show how beliefs, goals, values, or relationships changed over time.                               |

## 6.5 Review and Curation

| **ID** | **Priority** | **Requirement**                                            | **Acceptance criteria**                                                                             |
|--------|--------------|------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| FR-030 | Must         | Route all generated interpretations to review.             | Agent-generated notes and claims begin as unreviewed or agent_generated.                            |
| FR-031 | Must         | Allow approve, edit, merge, reject, and deprecate actions. | User can curate generated outputs without deleting raw sources.                                     |
| FR-032 | Must         | Distinguish canonical and non-canonical data.              | Future assistants can filter to reviewed data only or include unreviewed hypotheses when requested. |
| FR-033 | Should       | Maintain a review queue.                                   | User can see pending notes, claims, and relationships sorted by date, confidence, or importance.    |
| FR-034 | Should       | Log review decisions.                                      | Approved, edited, rejected, and deprecated items include timestamps and optional notes.             |

## 6.6 Retrieval, Summaries, and Visualization

| **ID** | **Priority** | **Requirement**                                 | **Acceptance criteria**                                                                                          |
|--------|--------------|-------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| FR-035 | Should       | Search notes and artifacts by semantic meaning. | User can retrieve relevant notes even when keywords differ.                                                      |
| FR-036 | Should       | Search by metadata.                             | User can filter by note type, source type, date, confidence, review status, and tags.                            |
| FR-037 | Should       | Generate a Nous summary.                  | System can produce a Markdown report of core values, beliefs, patterns, memories, contradictions, and questions. |
| FR-038 | Could        | Provide a memory chat interface.                | Assistant answers questions with citations to notes, claims, and artifacts.                                      |
| FR-039 | Could        | Generate visual graph views.                    | System can produce views for value graph, belief graph, project graph, timeline, and contradiction map.          |

## 6.7 Future Interpersonal Graph

| **ID** | **Priority** | **Requirement**                                                    | **Acceptance criteria**                                                                                        |
|--------|--------------|--------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| FR-F01 | Future       | Allow trusted people to create self-authored profiles.             | Friends can define themselves rather than being defined by the primary user.                                   |
| FR-F02 | Future       | Support relationship-specific shared context.                      | Shared memories, projects, boundaries, and mutual notes can connect two people.                                |
| FR-F03 | Future       | Separate contributor-authored data from user-authored impressions. | System clearly distinguishes what a friend says about themself from what the user says about the relationship. |
| FR-F04 | Future       | Provide consent and visibility controls.                           | Contributors can choose what is private, shared, connected, or deleted.                                        |
| FR-F05 | Future       | Handle conflicting memories or interpretations.                    | The system supports multiple perspectives without forcing a single truth.                                      |

# 7. Non-Functional Requirements

| **ID**  | **Category**          | **Requirement**                                           | **Acceptance criteria**                                                                                        |
|---------|-----------------------|-----------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| NFR-001 | Privacy               | User data must remain private by default.                 | No artifact, note, graph node, or generated claim is shared externally without explicit user action.           |
| NFR-002 | Security              | Local-first storage is preferred for MVP.                 | The MVP should work with local files and avoid unnecessary cloud dependency.                                   |
| NFR-003 | Provenance            | Every generated claim must be traceable.                  | Claims and relationships point back to evidence notes or raw artifacts.                                        |
| NFR-004 | Auditability          | Generated content must declare method and status.         | Metadata includes source, extraction method, confidence, created date, and review status.                      |
| NFR-005 | Data quality          | The system must avoid vault pollution.                    | Generated items go to inbox first; canonical model only includes reviewed or intentionally accepted content.   |
| NFR-006 | Interpretation safety | The agent must avoid unsupported psychological certainty. | The agent labels uncertain interpretations as hypotheses and uses confidence levels.                           |
| NFR-007 | Recoverability        | Raw data must not be destroyed during processing.         | Imports are additive; original artifacts are preserved or linked.                                              |
| NFR-008 | Interoperability      | MVP should use open, portable formats.                    | Markdown, YAML, JSON, and local file paths are preferred.                                                      |
| NFR-009 | Maintainability       | Schemas must be versioned.                                | Note templates and graph schema include version identifiers to allow migration.                                |
| NFR-010 | Extensibility         | The architecture must support future modules.             | Memory chat, visualization, and interpersonal graph can be added without rewriting capture pipeline.           |
| NFR-011 | Performance           | Interactive operations should feel fast for personal use. | Single-note capture and generation should not require heavy manual steps; batch operations can run separately. |
| NFR-012 | Reliability           | Graph generation should be repeatable.                    | Running extraction twice over the same reviewed data should not create duplicate canonical nodes.              |
| NFR-013 | Usability             | Daily capture must be low friction.                       | The user can submit quick text or voice-derived reflections without filling long forms.                        |
| NFR-014 | Explainability        | Assistant answers should cite sources.                    | Memory chat and summaries cite reviewed notes, claims, and artifacts wherever possible.                        |
| NFR-015 | Boundary control      | Other people data must be carefully separated.            | Future interpersonal module separates self-authored contributor data, user impressions, and system hypotheses. |

# 8. User Flows

### UF-001: Quick Reflection Capture

| **Field**          | **Details**                                                                              |
|--------------------|------------------------------------------------------------------------------------------|
| Primary actor      | Primary user                                                                             |
| Trigger            | User writes or dictates a thought about themself.                                        |
| Preconditions      | Obsidian vault exists; capture input can be saved as text or transcript.                 |
| Successful outcome | Raw artifact is preserved; draft notes and candidate relationships are ready for review. |

> Main flow:
>
> 1\. User submits a raw text reflection or a voice transcript.
>
> 2\. System creates a raw artifact record with timestamp and source
> metadata.
>
> 3\. Archivist agent segments the input into possible note candidates.
>
> 4\. Agent creates draft notes in Agent Inbox, such as reflection,
> belief, value, question, or pattern.
>
> 5\. Agent suggests relationships to existing notes and labels any
> interpretation as tentative.
>
> 6\. System adds items to review queue.
>
> Design notes:

- The agent should not decide what the thought ultimately means.

- Fast capture matters more than perfect classification.

### UF-002: Import Old Writing

| **Field**          | **Details**                                                                                |
|--------------------|--------------------------------------------------------------------------------------------|
| Primary actor      | Primary user                                                                               |
| Trigger            | User drops an old essay, journal entry, blog post, or document into the raw archive.       |
| Preconditions      | File is readable or convertible to text; import folder exists.                             |
| Successful outcome | Writing becomes evidence for future self-model claims without losing the original context. |

> Main flow:
>
> 1\. System detects or receives the writing artifact.
>
> 2\. System creates an artifact note with title, date if known, file
> path, and import metadata.
>
> 3\. Agent summarizes the writing conservatively.
>
> 4\. Agent extracts candidate themes, beliefs, identity statements,
> values, memories, or claims.
>
> 5\. Agent links all extracted notes back to the source artifact.
>
> 6\. User later reviews, edits, approves, or rejects extracted claims.
>
> Design notes:

- Old writing may represent past self, not current self. Generated
  claims should include temporal context.

### UF-003: Import Photo or Screenshot

| **Field**          | **Details**                                                            |
|--------------------|------------------------------------------------------------------------|
| Primary actor      | Primary user                                                           |
| Trigger            | User adds a photo, screenshot, or visual artifact.                     |
| Preconditions      | Image file can be stored in raw artifacts folder.                      |
| Successful outcome | Image becomes a memory anchor and source-backed artifact in the vault. |

> Main flow:
>
> 1\. System creates a photo artifact note with file path,
> created/imported date, and metadata if available.
>
> 2\. Agent records visible content separately from user-provided
> context.
>
> 3\. If user adds context, agent creates memory, project, person, or
> place links as appropriate.
>
> 4\. Agent may suggest emotional or thematic relationships only as
> hypotheses.
>
> 5\. User reviews the artifact note and any generated links.
>
> Design notes:

- The system should not invent the emotional meaning of an image.

- Face recognition or identification of people should require careful
  consent and explicit user confirmation.

### UF-004: Import Project Artifact

| **Field**          | **Details**                                                                                   |
|--------------------|-----------------------------------------------------------------------------------------------|
| Primary actor      | Primary user                                                                                  |
| Trigger            | User imports a README, design doc, prototype screenshot, repository summary, or project note. |
| Preconditions      | Project artifact exists and can be referenced from the vault.                                 |
| Successful outcome | Project is represented as both a source artifact and a self-knowledge node.                   |

> Main flow:
>
> 1\. System creates an artifact note for the project source.
>
> 2\. Agent creates or updates a Project note.
>
> 3\. Agent extracts possible skills, values expressed, recurring
> themes, and project motivations.
>
> 4\. Agent proposes relationships such as Project expresses Value or
> Project evidences Pattern.
>
> 5\. User reviews candidate project metadata and claims.
>
> Design notes:

- Projects are high-signal evidence because they represent chosen
  behavior, not only self-description.

### UF-005: Review Agent-Generated Notes

| **Field**          | **Details**                                                                   |
|--------------------|-------------------------------------------------------------------------------|
| Primary actor      | Reviewer self                                                                 |
| Trigger            | User opens the Agent Inbox or review queue.                                   |
| Preconditions      | There are unreviewed generated notes, claims, or relationships.               |
| Successful outcome | The canonical self-model improves without allowing agent noise to accumulate. |

> Main flow:
>
> 1\. System displays unreviewed items with source, confidence, and
> suggested action.
>
> 2\. User opens each item and compares it against the raw artifact or
> transcript.
>
> 3\. User chooses approve, edit, merge, reject, or defer.
>
> 4\. Approved items move into reviewed notes or canonical model.
>
> 5\. Rejected items remain logged but are excluded from canonical
> outputs unless requested.
>
> 6\. System updates review status and timestamps.
>
> Design notes:

- Review is the main quality-control mechanism.

- The user should be able to batch-review low-risk metadata but
  carefully review interpretive claims.

### UF-006: Generate or Refresh Nous Summary

| **Field**          | **Details**                                                             |
|--------------------|-------------------------------------------------------------------------|
| Primary actor      | Primary user                                                            |
| Trigger            | User requests a generated summary of the self-model.                    |
| Preconditions      | There are reviewed notes or selected unreviewed items available.        |
| Successful outcome | User receives an up-to-date, source-backed map of their self-knowledge. |

> Main flow:
>
> 1\. System reads relevant reviewed notes, claims, and graph data.
>
> 2\. System produces a Markdown summary with core values, beliefs,
> memories, projects, patterns, contradictions, and open questions.
>
> 3\. Each major statement cites or links to source notes or claims.
>
> 4\. System writes the output to the Generated folder.
>
> 5\. User can review the summary and flag inaccurate statements.
>
> Design notes:

- The summary should include uncertainty and contradictions rather than
  over-smoothing the user into a single identity.

### UF-007: Ask Memory Question

| **Field**          | **Details**                                                               |
|--------------------|---------------------------------------------------------------------------|
| Primary actor      | Future memory assistant user                                              |
| Trigger            | User asks a question such as: What do I keep returning to in my projects? |
| Preconditions      | Semantic search or retrieval is available; reviewed data exists.          |
| Successful outcome | User receives a grounded answer based on their own memory system.         |

> Main flow:
>
> 1\. Assistant interprets the query and searches reviewed notes,
> artifacts, claims, and graph edges.
>
> 2\. Assistant retrieves relevant evidence and separates reviewed facts
> from hypotheses.
>
> 3\. Assistant answers with citations to notes, claims, and artifacts.
>
> 4\. Assistant identifies uncertainty or missing evidence.
>
> 5\. User can request deeper analysis or ask the system to create a new
> reflection note from the interaction.
>
> Design notes:

- This should not be treated as an oracle. It is a retrieval and
  reflection tool.

### UF-008: Future Friend Self-Profile Update

| **Field**          | **Details**                                                                                      |
|--------------------|--------------------------------------------------------------------------------------------------|
| Primary actor      | Future friend/contributor                                                                        |
| Trigger            | A trusted person wants to update who they are and connect context to the user.                   |
| Preconditions      | Interpersonal module exists; contributor has consented and has an account or secure access.      |
| Successful outcome | The system creates a consent-based relationship graph without collapsing different perspectives. |

> Main flow:
>
> 1\. Contributor creates or updates their self-authored profile.
>
> 2\. Contributor chooses visibility level for each piece of data.
>
> 3\. Contributor optionally creates shared memories, shared projects,
> boundaries, or relationship notes.
>
> 4\. System keeps contributor-authored data separate from user-authored
> impressions.
>
> 5\. Primary user can see only data the contributor has chosen to
> share.
>
> 6\. Both parties can later revise, hide, or delete their own
> contributions.
>
> Design notes:

- This flow is out of MVP scope.

- The central principle is: they define themselves; the user defines
  their experience; the system labels hypotheses separately.

# 9. Suggested Vault Structure

/Nous
/00 Raw Artifacts
/Audio
/Photos
/Writing
/Projects
/Screenshots
/Chats
/Transcripts
/01 Agent Inbox
/Unreviewed Memories
/Unreviewed Beliefs
/Unreviewed Claims
/Unreviewed Links
/02 Notes
/Memories
/Values
/Beliefs
/Decisions
/People
/Projects
/Patterns
/Questions
/Contradictions
/03 Canonical Model
/Claims
/Core Values
/Identity
/Current Goals
/Life Timeline
/04 Generated
Nous.md
Knowledge Graph.json
Timeline.md
Contradiction Map.md
Clone Context.md
/99 Future Modules
Interpersonal Graph.md

# 10. MVP Milestones

| **Milestone**              | **Deliverable**                                   | **Success condition**                                                                                    |
|----------------------------|---------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| M1: Vault schema           | Folder structure, note templates, YAML schema.    | Manual notes can be created consistently.                                                                |
| M2: Basic ingestion        | Script or agent path for text/transcript imports. | A raw input becomes artifact note plus draft Obsidian notes.                                             |
| M3: Review queue           | Inbox and review status workflow.                 | User can approve, edit, merge, reject, and canonicalize outputs.                                         |
| M4: Graph export           | JSON export for nodes and relationships.          | Reviewed notes generate stable graph records.                                                            |
| M5: Nous report      | Generated Markdown summary.                       | User gets a source-backed summary of values, beliefs, patterns, memories, contradictions, and questions. |
| M6: Raw artifact expansion | Import support for writing, photos, and projects. | Different raw data types produce source-backed notes.                                                    |

# 11. Open Product Questions

- What is the minimum metadata required before capture becomes annoying?

- Which note types should be canonical from day one, and which can wait?

- Should claims be separate Markdown notes, embedded YAML records, or
  both?

- What review cadence is realistic: daily, weekly, or monthly?

- How should the system handle past-self versus current-self claims?

- What should the first visualization be: value map, timeline, project
  graph, or contradiction map?

- When should semantic search be added: before or after the first graph
  export?

- What is the boundary between helpful self-analysis and
  over-interpretation?

- What consent model would be needed before the interpersonal graph is
  safe to build?

# 12. Appendix: Example Metadata

## 12.1 Generated Note Frontmatter

---
type: belief
schema_version: 0.1
status: draft
review_status: agent_generated
confidence: medium
created: 2026-06-06
source:
type: transcript
path: 00 Raw Artifacts/Transcripts/2026-06-06-reflection.md
extraction:
method: archivist_agent
interpretation_level: low
related_values: \[\]
related_memories: \[\]
---

## 12.2 Claim Object

{
"id": "claim_0001",
"type": "claim",
"claim_type": "pattern",
"statement": "I tend to turn personal problems into systems-building
projects.",
"confidence": 0.72,
"status": "agent_generated",
"evidence": \["Project - Nous", "Reflection - Preserving parts of
myself"\],
"counterevidence": \[\],
"first_seen": "2026-06-06",
"last_updated": "2026-06-06"
}
