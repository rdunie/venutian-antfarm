# Documentation Style Guide

Standards for all project documentation. Every agent that creates or updates documentation must follow these guidelines.

## General Principles

- **Active voice, second person** for guides and instructions. "You will see..." not "The following will be displayed."
- **No em dashes.** Use commas, periods, or parentheses instead.
- **Plain language first.** Avoid jargon. When system-specific terms are needed, explain naturally in context.

## Markdown Structure

- **Single H1** per document (the title)
- **No skipped heading levels.** H1 then H2 then H3 (never H1 then H3)
- **Maximum depth H4** for governance docs; H5 acceptable for technical docs
- **Consistent list markers.** Use `-` (not `*`) throughout the project
- **No trailing whitespace.** Maximum 1 blank line between sections.
- **Tables:** Maximum 5 columns preferred. 6-7 require short headers (<15 chars). 8+ must be restructured.
- **Cell content:** Keep under 80 characters per cell where possible.

## Mermaid Diagrams

All diagrams must follow the shared color palette.

**Color palette:**

| Semantic | Background | Border    | Use for                              |
| -------- | ---------- | --------- | ------------------------------------ |
| Green    | `#a5d6a7`  | `#2e7d32` | Completed, success, active processes |
| Blue     | `#90caf9`  | `#1565c0` | User-facing, actors, strategic       |
| Orange   | `#ffcc80`  | `#e65100` | Decisions, warnings, external        |
| Red      | `#ef9a9a`  | `#b71c1c` | Blocked, compliance, critical        |
| Grey     | `#bdbdbd`  | `#424242` | Infrastructure, neutral              |

Colors are Material Design 300-level tones. Always include `color:#1a1a1a` in every style directive to force dark text, ensuring readability on both light and dark backgrounds.

**Node shapes:**

| Shape            | Meaning             |
| ---------------- | ------------------- |
| Cylinder `[( )]` | Database            |
| Stadium `([ ])`  | Actor / user role   |
| Rectangle `[ ]`  | Service / component |
| Rounded `( )`    | Process / workflow  |
| Diamond `{ }`    | Decision            |

**Diagram constraints:**

- Maximum 15 nodes per diagram (split complex diagrams)
- Maximum 5 subgraphs
- Edge labels under 30 characters

## Cross-References

- **Always use relative paths** for internal links
- **Bidirectional linking:** If doc A references doc B, doc B should reference back
- **Anchor links** must match actual heading text

## DRY Documentation

See `.claude/COLLABORATION.md` section on DRY Documentation for the full policy. In summary:

- **Default:** Cross-link to the source of truth. Do not duplicate.
- **Exceptions must declare:** source of truth, why duplicated, sync requirement
- Acceptable exception reasons: agent reliability, audience targeting, audit snapshots, performance indexes

## Documentation Ownership

Each agent maintains documentation within its domain:

| Domain        | Agent              | Key Docs                 |
| ------------- | ------------------ | ------------------------ |
| Collaboration | scrum-master       | .claude/COLLABORATION.md |
| Architecture  | solution-architect | Architecture docs        |
| Roadmap       | product-owner      | docs/plans/              |
| Agent defs    | (each agent)       | .claude/agents/          |
| Metrics       | platform-ops       | ops/ scripts, dashboards |
| Doc quality   | (all agents)       | This file                |
