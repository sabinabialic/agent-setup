---
name: orchestrating-feature-implementation
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

Inspect the brief, repository instructions, relevant files, conventions,
acceptance criteria, and available test commands before implementation. Treat
every ambiguous requirement as a blocking open question with an owner; do not
invent behavior. Block implementation affected by the ambiguity until the
question is resolved. Continue only with work demonstrably unaffected by that
ambiguity, and record the boundary and its evidence in the worklog.

During `discovery`, optionally dispatch read-only `explore` or `general` agents
in parallel to gather architecture research, test strategy, and cross-cutting
concerns. This step is optional and valuable for large, ambiguous features
where wider reconnaissance before planning pays off. Record findings in the
worklog's Discoveries section before entering `planned`.

Discovery agents do not edit source, tests, generated artifacts, or the
worklog. Reconcile their evidence in the worklog before entering `planned`.

## Planning And Edits

In `planned`, dispatch the `planner` subagent (read-only, writes `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md`).
Pass the feature brief, any discovery findings, and acceptance criteria. The
planner explores the codebase, designs the change, enumerates edge cases, and
produces a specification with exact file paths, function signatures, and data flow.

**Conductor gate on ambiguity:** The planner may flag unresolved interpretations
in the spec. Review these explicitly: if the ambiguity truly blocks implementation,
record it as an open question in the worklog, block the affected work, and escalate
to the user for a decision before proceeding. If the planner's chosen interpretation
is sound and demonstrably unaffected by the uncertainty, record the assumption
and continue. Never silently accept an ambiguous spec.

Reset `.pipeline/<YYYY-MM-DD>-<feature-slug>/` (remove stale `spec.md`, `changes.md`, `tests.md`, `review.md`
from prior runs) before dispatching the planner. The slug matches the worklog filename (e.g., `add-dark-mode`), and the full path is `.pipeline/<YYYY-MM-DD>-<slug>/` to organize multiple features. Same-day reruns overwrite only their own subfolder; sibling features remain untouched.

In `implementing`, delegate one implementation or fix task at a time, dispatching
the `coder` subagent (reads `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md`, writes `.pipeline/<YYYY-MM-DD>-<feature-slug>/changes.md`).
Instruct it to implement only the assigned slice of the spec. Serial execution
is the default. Parallel edits are allowed only when the conductor explicitly
assigns disjoint files and the agents cannot affect shared interfaces or generated
artifacts. Inspect each diff and log it to the worklog's Implementation Log section.

Only assigned implementation agents edit code. Only the conductor merges reports
into shared worklog state. Preserve unexpected unrelated worktree changes after
inspecting them; do not revert them without authorization. An unauthorized file,
interface, or generated-artifact change is a blocking finding: stop progress,
record the evidence, and create an explicit fix task before any dependent work
continues. Inspection alone does not clear the finding.

## Testing, Review, And Iteration

In `testing`, dispatch the `tester` subagent (reads `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md` and
`.pipeline/<YYYY-MM-DD>-<feature-slug>/changes.md`, writes `.pipeline/<YYYY-MM-DD>-<feature-slug>/tests.md`). It discovers the project's
test framework and conventions, then writes tests covering the happy path and all
edge cases enumerated in the spec. The tester runs tests and reports exact commands,
results, and failures. Tester agents do not silently repair production code; a
failed test remains evidence and becomes an explicit fix task.

In `reviewing`, dispatch the `reviewer` subagent (read-only, returns a PASS/FAIL
verdict). It reads `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md`, `.pipeline/<YYYY-MM-DD>-<feature-slug>/changes.md`, and `.pipeline/<YYYY-MM-DD>-<feature-slug>/tests.md`,
inspects the actual source changes, and judges spec conformance, correctness,
security, reliability, maintainability, and edge-case coverage. The conductor
captures the reviewer's verdict text verbatim and writes it to `.pipeline/<YYYY-MM-DD>-<feature-slug>/review.md`,
then records findings (severity, evidence, triggering scenario, recommendation) in
the worklog's Review Findings section. Preserve all findings, including dismissed
ones, with their disposition.

In `iterating`, convert each blocking finding into a worklog task. Apply fixes
serially: dispatch the `coder` subagent again to address the specific blocking
issues, re-run the `tester`, and re-run the `reviewer`. Record the iteration in
the worklog with timestamp, fixed issue, and outcome. Do not skip a loop because
a change is small, expensive, urgent, or previously appeared correct. Unlike the
autonomous `/ship` pipeline, orchestration has no retry cap — loop until the
verdict is PASS or the conductor/user decides to stop. Record all findings and
disposition rather than silently resolving them.

## Completion Gate

Enter `complete` only after fresh command-level verification following the last
change. Run the narrowest relevant checks during iteration and the project's
final test, lint, type-check, or build commands when available. Record exact
commands, outcomes, and run context in the worklog. Completion verification must
reference the `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md`, `.pipeline/<YYYY-MM-DD>-<feature-slug>/changes.md`, `.pipeline/<YYYY-MM-DD>-<feature-slug>/tests.md`,
and `.pipeline/<YYYY-MM-DD>-<feature-slug>/review.md` artifacts as evidence. Report unverified areas,
remaining risks, unresolved questions, and changed files explicitly. A report
that merely says "tests pass" is not verification.

Completion is forbidden when required verification is missing or blocking
questions/findings remain. Record ambiguity, disagreement, failed checks,
superseded assumptions, and worktree concerns rather than silently resolving or
omitting them.

## Supporting Contracts

- [Worklog template](worklog-template.md)
- [Agent contract](agent-contract.md)
