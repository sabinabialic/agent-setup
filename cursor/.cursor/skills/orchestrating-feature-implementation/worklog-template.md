# Feature: <name>

## Source Brief
- Source document or session context:
- Goal:
- Acceptance criteria:

## Current Plan
- [ ] Task

## Constraints and Conventions
- Repository patterns
- Test commands
- Explicit non-goals

## Decisions
- [timestamp] Decision, alternatives considered, and reason

## Discoveries
- [timestamp] Evidence from code, docs, tests, or runtime behavior

## Implementation Log
- [timestamp] Agent, files changed, summary, verification

## Review Findings
- [timestamp] Finding, severity, evidence, disposition

## Verification
- Command:
- Result:
- Remaining risks:

## Open Questions
- Question, owner, and blocking status

## Update Rules

- Preserve the source brief and any original plan as immutable history. Do not
  rewrite or remove them when later information changes the interpretation.
- Append new knowledge with a timestamp to the section that owns it. Include
  evidence and the reporting agent where applicable.
- Mark an outdated decision, assumption, discovery, or plan item as
  **superseded** in place, state what superseded it and why, then append the
  replacement entry. Never delete the superseded record.
- Preserve conflicting reports and unresolved ambiguity. Record the competing
  evidence and disposition rather than silently choosing or rewriting a report.
- Agents may read the worklog and return reports, but only the conductor merges
  reports into shared worklog state and updates its sections after
  reconciliation.
- Record every phase transition or rollback with its timestamp, reason, and
  evidence. Failed checks remain recorded and become explicit follow-up work.
