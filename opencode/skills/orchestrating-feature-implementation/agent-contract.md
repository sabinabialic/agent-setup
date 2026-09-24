# Agent Contract

This skill dispatches the `/ship` pipeline's specialized subagents—`planner`,
`coder`, `tester`, and `reviewer`—which operate on `.pipeline/<YYYY-MM-DD>-<feature-slug>/*.md` artifacts
as their handoff and report mechanism. The worklog is the durable, append-only
audit trail; `.pipeline/<YYYY-MM-DD>-<feature-slug>/` is the scratch layer for the subagents' native contracts.

Every delegated agent must read the current worklog before acting. The worklog
path is authoritative for assignment scope and phase state. Agents return
structured reports (written to `.pipeline/<YYYY-MM-DD>-<feature-slug>/*.md`); they do not merge their own
report into the worklog. Only the conductor reconciles reports and updates
shared worklog state.

## Common Handoff
- Worklog path and current phase
- Feature brief and assigned scope
- Files allowed to change
- Acceptance criteria relevant to the assignment
- Commands expected to run

The handoff must also identify the agent role, dependencies, exclusions, and
whether the assignment is read-only. Implementation and fix handoffs must
state that unrelated files and shared interfaces outside the assigned scope
are excluded. The agent must report any scope conflict before changing files.

## Required Report
- Conclusions
- Evidence and file/line references
- Files changed
- Commands run and exact results
- Failures or unresolved questions
- Recommended next steps

Reports must distinguish observed facts, assumptions, and recommendations.
Tests and other checks must include the exact command and outcome. A report
does not constitute completion; the conductor decides status after reconciling
the evidence and recording it in the worklog.

## Role Boundaries

### Discovery and Planning: `planner` Subagent

The `planner` subagent is dispatched once during the `planned` phase.

**Input handoff:**
- Worklog path and current phase
- Feature brief and acceptance criteria
- Any discovery findings from prior `explore`/`general` agents (optional)
- Repository conventions and test commands

**Behavior:**
- Reads `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md` on retry if this is a revision attempt (indicated by existing spec).
- Explores the codebase (files, existing patterns, similar features).
- Designs the change: exact files to create/modify, function signatures, data flow.
- Enumerates edge cases explicitly — this list is the tester's coverage contract.
- Writes to `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md` containing: Summary, Files, Functions & signatures,
  Data flow, Edge cases (numbered list of concrete scenarios), Out of scope.
- Flags any ambiguities or unresolved interpretations in the spec itself.
- **Does not** modify any source files (spec.md only).

**Conductor reconciliation gate:**
Review the planner's flagged ambiguities. If an ambiguity truly blocks
implementation, record it as an open question in the worklog with an owner
and blocking status, then escalate to the user. If the planner's interpretation
is sound, record the assumption and continue. Do not silently accept an ambiguous
spec.

### Implementation and Fix: `coder` Subagent

The `coder` subagent is dispatched once per scoped implementation task or fix,
serial by default.

**Input handoff:**
- Worklog path and current phase
- `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md` path (to read), provided by orchestrator
- Assigned scope (which files, which functions, allowed changes)
- Files allowed to change; files/interfaces excluded from this task
- If retrying a FAIL: the reviewer's blocking issues verbatim
- No unrelated edits permitted

**Behavior:**
- Reads `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md` in full before writing any code.
- Implements exactly the assigned scope and nothing more.
- Follows existing codebase conventions.
- Writes to `.pipeline/<YYYY-MM-DD>-<feature-slug>/changes.md` containing: Summary, Files changed (with notes),
  Deviations (if any), Notes for tester.
- **Does not** write tests (the tester's job).
- **Does not** repair production code silently to make tests pass.
- If the spec is genuinely impossible or internally contradictory, reports
  `## BLOCKED` in changes.md instead of guessing.

**Conductor inspection:**
After each coder invocation, inspect the diff. Log it to the worklog's
Implementation Log. Any unauthorized file, shared-interface, or generated-artifact
change is a blocking finding — stop, record the exact evidence, and create an
explicit fix task before any dependent work continues.

### Testing: `tester` Subagent

The `tester` subagent is dispatched once in the `testing` phase, and again on
each iteration following a coder fix.

**Input handoff:**
- Worklog path and current phase
- `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md` and `.pipeline/<YYYY-MM-DD>-<feature-slug>/changes.md` paths, provided by orchestrator
- Targeted scope (which functions/modules/changes to test)
- Allowed test files/frameworks
- Acceptance criteria relevant to the test
- Expected test commands

**Behavior:**
- Reads both spec.md (edge-case list is the coverage checklist) and changes.md
  (what was actually built).
- Discovers the project's existing test framework and conventions; matches them.
- Writes tests covering: happy path for each behavior, every edge case from spec.
- Runs tests and captures exact commands and results.
- Writes to `.pipeline/<YYYY-MM-DD>-<feature-slug>/tests.md` containing: Test files, Coverage map (spec edge case
  → test), Results (pass/fail counts, failure details).
- **Does not** weaken or delete a failing test to obtain a passing result.
- **Does not** modify production code to make tests pass.

### Reviewing: `reviewer` Subagent

The `reviewer` subagent is dispatched once in the `reviewing` phase, and again
on each iteration following a coder fix.

**Input handoff:**
- Worklog path and current phase (read-only reference)
- `.pipeline/<YYYY-MM-DD>-<feature-slug>/spec.md`, `.pipeline/<YYYY-MM-DD>-<feature-slug>/changes.md`, `.pipeline/<YYYY-MM-DD>-<feature-slug>/tests.md` paths, provided by orchestrator
- Files the coder changed (for inspection)

**Behavior:**
- Works strictly read-only. Does not modify files, run commands, or fix anything.
- Reads the three `.pipeline/<YYYY-MM-DD>-<feature-slug>/*.md` artifacts and inspects the actual source changes
  using `read`, `grep`, `glob`.
- Evaluates: Spec conformance, Correctness, Edge-case coverage (every spec edge
  case has a real, passing test), Scope, Quality/conventions.
- Returns a PASS/FAIL verdict as its final response message, with this shape:
  ```
  VERDICT: PASS   (or)   VERDICT: FAIL

  ## Reasoning
  <concise justification>

  ## Blocking issues        (only if FAIL)
  1. <specific, actionable problem tied to file/function>
  2. ...

  ## Non-blocking notes     (optional)
  - <minor suggestions>
  ```
- The verdict is judged against the spec, not personal preference.
- FAIL if: spec not met, a real bug exists, tests failing, or a spec edge case
  has no meaningful test. Otherwise PASS.

**Conductor gate:**
Capture the reviewer's verdict text verbatim. Write it to `.pipeline/<YYYY-MM-DD>-<feature-slug>/review.md`.
Record findings in the worklog's Review Findings section with severity, evidence,
and disposition. Preserve all findings, including dismissed ones. If VERDICT is
FAIL, convert each blocking issue into a worklog task, re-dispatch the coder,
then re-run the tester and reviewer. Continue looping until PASS (no retry cap)
or the conductor/user stops.

### Conductor

- Supplies the handoff, assigns scope, ensures agents read the current worklog
  before acting, and reconcile their evidence.
- Manages `.pipeline/<YYYY-MM-DD>-<feature-slug>/` lifecycle: resets it before the planner, preserves it
  across phases for the agents' native contract.
- Keeps the worklog as durable, append-only state. Records every phase transition,
  decision, discovery, implementation, and review finding with timestamp, reason,
  and evidence. Never deletes; mark superseded items in place.
- Serializes implementation and fix work by default; permits parallel edits only
  for explicitly disjoint files with no shared interfaces or generated artifacts.
- Preserves disagreement, superseded assumptions, failures, and residual risk in
  the worklog, and owns phase transitions, follow-up assignments, and final status.
