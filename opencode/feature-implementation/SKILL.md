---
name: feature-implementation
description: Use when implementing a feature from a source document or current-session context and the work benefits from delegated discovery, testing, review, or an evolving shared plan.
---

# Orchestrating Feature Implementation

## Conductor Principle

The primary agent is the conductor and delegates by default. It owns scope,
phase transitions, report reconciliation, the shared worklog, follow-up work,
and final status. The worklog is durable operational state, not a substitute
for the source brief or original plan.

Use this exact phase sequence:

```text
intake -> discovery -> planned -> implementing -> testing -> reviewing -> iterating -> complete
```

Record every transition and rollback in the worklog with a timestamp, reason,
and evidence. A failure or new discovery returns the workflow to the earliest
affected phase.

## Intake And Discovery

Create or adopt `docs/worklogs/<feature-slug>.md`. Preserve the source brief
and original plan; append new knowledge with timestamps and mark superseded
assumptions rather than deleting them. Every agent reads the current worklog
before acting and returns the fields in the [Agent contract](agent-contract.md).

Use `docs/feature-learnings.md` as a curated, cross-feature record. Before
acting, inspect it for applicable verified guidance. The worklog remains the
complete feature record; do not create a separate learnings file per feature
or copy routine operational detail into the curated record.

Inspect the brief, repository instructions, relevant files, conventions,
acceptance criteria, and available test commands before implementation. Treat
every ambiguous requirement as a blocking open question with an owner; do not
invent behavior. Block implementation affected by the ambiguity until the
question is resolved. Continue only with work demonstrably unaffected by that
ambiguity, and record the boundary and its evidence in the worklog.

During `discovery`, dispatch independent read-only agents in parallel for:

- codebase architecture and conventions;
- requirement and acceptance-criteria extraction;
- risk and test planning.

Discovery agents do not edit source, tests, generated artifacts, or the
worklog. Reconcile their evidence in the worklog before entering `planned`.

## Planning And Edits

In `planned`, define scoped tasks, dependencies, ownership, allowed files,
exclusions, acceptance criteria, and expected commands. Include unresolved
questions and their blocking status.

In `implementing`, delegate one implementation or fix task at a time and
inspect its diff afterward. Serial execution is the default. Parallel edits
are allowed only when the conductor explicitly assigns disjoint files and the
agents cannot affect shared interfaces or generated artifacts. Every edit
handoff states scope, allowed files, exclusions, and no-unrelated-edits.

Only assigned implementation agents edit code. Testing agents do not silently
repair production code. Only the conductor merges reports into shared
worklog state. Preserve unexpected unrelated worktree changes after inspecting
them; do not revert them without authorization. An unauthorized file,
interface, or generated-artifact change is a blocking finding: stop progress,
record the evidence, and create an explicit fix task before any dependent work
continues. Inspection alone does not clear the finding.

## Testing, Review, And Iteration

In `testing`, run the narrowest relevant existing checks for the changed scope
and record the exact command and result. Add a new test only when it covers a
meaningful regression risk, non-trivial behavior, or an explicit acceptance
criterion that existing checks do not cover. Do not add tests solely to raise
coverage or to exercise trivial wiring, formatting, or unchanged behavior.
When new coverage is justified, delegate its creation or execution to a
specialized testing agent using the testing-agent handoff/report contract in
the [Agent contract](agent-contract.md); otherwise, delegate execution of the
existing checks only. Record why new tests were added or why existing checks
were sufficient.
The testing agent reports exact commands, results, failures, and unresolved
production fixes; it does not silently repair production code. A failed test
remains evidence, is not weakened or deleted, and becomes an explicit fix task.

In `reviewing`, dispatch independent read-only reviews in parallel for:

- requirements and acceptance-criteria compliance;
- correctness, security, reliability, and maintainability.

Record every finding, including dismissed findings, with severity, evidence,
disposition, and residual risk. Preserve conflicting reports; resolve them with
repository evidence, tests, or an explicit user decision.

In `iterating`, convert each failure or blocking finding into a worklog task,
apply fixes serially, and rerun affected tests and reviews. Do not skip a loop
because a change is small, expensive, urgent, or previously appeared correct.

## Completion Gate

Enter `complete` only after fresh command-level verification following the last
change. Run the narrowest relevant checks during iteration and the project's
final test, lint, type-check, or build commands when available. Record exact
commands, outcomes, and run context in the worklog. Report unverified areas,
remaining risks, unresolved questions, and changed files explicitly. A report
that merely says “tests pass” is not verification.

At completion, the conductor reviews reported learning candidates and promotes
only guidance that is verified, reusable, and actionable to
`docs/feature-learnings.md`. Each promoted entry links to its source worklog,
states where it applies, and identifies a review trigger where appropriate.
Exclude transient debugging notes, feature-specific detail, unverified
hypotheses, secrets, and duplicated worklog evidence. Mark outdated guidance
as superseded instead of deleting it. Recording that no candidate qualified is
valid and needs no curated-file update.

Completion is forbidden when required verification is missing or blocking
questions/findings remain. Record ambiguity, disagreement, failed checks,
superseded assumptions, and worktree concerns rather than silently resolving or
omitting them.

## Supporting Contracts

- [Worklog template](worklog-template.md)
- [Agent contract](agent-contract.md)
