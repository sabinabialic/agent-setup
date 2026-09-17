# Agent Contract

Every delegated agent must read the current worklog before acting. The
worklog path is authoritative shared state for the assignment. Agents return a
structured report; they do not merge their own report into the worklog. Only
the conductor reconciles reports and updates shared state.

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
- Reusable learning candidates, including applicability and supporting evidence
- Recommended next steps

Reports must distinguish observed facts, assumptions, and recommendations.
Tests and other checks must include the exact command and outcome. A report
does not constitute completion; the conductor decides status after reconciling
the evidence and recording it in the worklog.

## Role Boundaries

### Discovery Agents

- Read the current worklog before acting.
- Work read-only and inspect requirements, repository architecture,
  conventions, acceptance criteria, and test strategy.
- Do not edit source, tests, generated artifacts, or the worklog.
- Return evidence, open questions, risks, and recommended next steps.

### Implementation and Fix Agents

- Read the current worklog before acting.
- Edit only the explicitly assigned scope and allowed files.
- Avoid unrelated changes and do not modify shared interfaces or generated
  artifacts outside the handoff.
- Any unauthorized file, shared-interface, or generated-artifact change is a
  blocking finding. Stop dependent progress, report the exact evidence, and
  require an explicit fix task before continuing; inspection alone is not a
  disposition.
- Do not weaken or delete a failing test to obtain a passing result.
- Run the commands required by the handoff and report the exact results.
- Do not merge reports or update shared worklog state.

### Testing Agents

- Read the current worklog before acting.
- Receive a handoff stating the targeted scope, allowed test files, relevant
  acceptance criteria, expected test commands, and whether test creation or
  execution is required.
- Create or run tests only for the assigned scope and report exact commands,
  results, and failures.
- Return a testing report containing conclusions, test files changed, exact
  commands and results, failing cases, unresolved production fixes, and
  recommended next steps before the conductor's final verification.
- Do not silently repair production code. A needed fix is an unresolved issue
  or an explicit follow-up assignment.
- Do not weaken or delete a failing test to obtain a passing result.

### Review Agents

- Read the current worklog before acting.
- Work read-only and report requirements, correctness, security, reliability,
  or maintainability findings as assigned.
- Each finding includes severity, file/line evidence, triggering scenario,
  impact, and recommendation.
- Do not edit source, tests, generated artifacts, or the worklog.

### Conductor

- Supplies the handoff, assigns scope, and ensures the agent reads the current
  worklog before acting.
- Merges reports into shared state only after reconciling their evidence.
- Serializes implementation and fix work by default; permits parallel edits
  only for explicitly disjoint files with no shared interfaces or generated
  artifacts.
- Preserves disagreement, superseded assumptions, failures, and residual risk
  in the worklog, and owns phase transitions, follow-up assignments, and final
  status.
- Decides whether verified, reusable, actionable candidates are promoted to
  `docs/feature-learnings.md`, records the disposition in the worklog, and
  marks outdated curated guidance as superseded.
