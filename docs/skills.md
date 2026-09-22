# Skills

Reference for the opencode skills in this repo. Each skill lives under
`opencode/<name>/SKILL.md` and is loaded by the agent when its `description`
trigger matches the task at hand. This page summarizes what each one does and
when it fires.

| Skill | Use it when | Core idea |
|-------|-------------|-----------|
| [pr-review](#pr-review) | Reviewing a branch/PR before merge | Staff-level, evidence-based risk triage |
| [writing-pr-descriptions](#writing-pr-descriptions) | Opening or rewriting a PR description | Optimize for maintainer review speed |
| [push-lock](#push-lock) | Multiple agents push to one shared branch | Git-native atomic lock ref |
| [feature-implementation](#feature-implementation) | Implementing a feature via delegated agents | Conductor + worklog orchestration |

A separate, more rigid alternative to `feature-implementation` — the four-stage
`/ship` pipeline (planner → coder → tester → reviewer) — is documented in the
[README](../README.md#ship-pipeline).

---

## pr-review

`opencode/pr-review/SKILL.md`

**What it does.** Reviews the code on a branch as a staff engineer, producing
evidence-based, actionable findings. It looks past local correctness to how the
change behaves under concurrency, production load, partial failure, evolving
requirements, and operational constraints. Every finding explains why it matters
and what could happen in production.

**When it fires.** Reviewing a branch or PR before merge, auditing a diff for
bugs/security/performance regressions, giving a second opinion before human
review, or evaluating production readiness.

**Key mechanics.**
- Scopes to the branch diff (e.g. `git diff main...HEAD`), not the whole repo.
- Uses a single independent, read-only reviewer on a strong reasoning model —
  never a fast/cheap model for final findings.
- Considers seven axes: correctness, edge cases/failure handling, concurrency,
  scalability/performance, security/privacy, reliability/operability, and
  maintainability/evolution.
- Every finding needs file/line evidence, a triggering scenario, and a concrete
  recommendation. Unsupported, unreachable, or preference-only findings are
  discarded before publishing.
- Output is grouped by file then severity (`Critical`/`High`/`Medium`/`Low`),
  ending with an overall risk level and merge recommendation.

---

## writing-pr-descriptions

`opencode/writing-pr-descriptions/SKILL.md`

**What it does.** Produces PR descriptions optimized for maintainer review
speed, clarity, and confidence — concise technical context, explicit review
order, and concrete, runnable testing steps.

**When it fires.** Opening a new PR, rewriting a weak description, updating PR
text after a scope change, or shipping stacked PRs that must be reviewed in
order.

**Key mechanics.**
- Prefers a repository template at `.github/pull_request_template.md` when
  present; otherwise falls back to `What & How` → `Why` → `Review Guide` →
  `Testing` → `Anything Else?`.
- Review Guide gives a fast path through the files, highest-signal first, and
  flags risky areas.
- Testing section is a checklist of actual runnable commands, including setup.
- Stacked PRs are always enumerated in merge order with the current PR
  highlighted.
- Quality bar: understandable without local notes, reviewer knows where to start
  in under 30 seconds, no process narration or fluff.

---

## push-lock

`opencode/push-lock/SKILL.md`

**What it does.** Serializes pushes when multiple agents write against the same
repository concurrently, so only the push step is mutually exclusive — edits,
tests, and review still run in parallel. Prevents non-fast-forward rejections,
lost commits, and force-push overwrites.

**When it fires.** Multiple agents may finish and push around the same time to a
*shared* branch. Not needed when each agent pushes to its own uniquely named
branch or when a single process owns all pushes.

**Key mechanics.**
- Uses a git-native atomic lock ref (`refs/locks/push`): creating the ref fails
  if it already exists, so exactly one concurrent attempt wins. No external
  coordination service, no local file/mutex.
- Retries with backoff; reclaims the lock only if older than a TTL (stale
  holder).
- After acquiring, always `git fetch` + rebase onto the remote tip before
  pushing — the lock guarantees exclusivity among cooperating agents, not
  freshness.
- Hold time is bounded: acquire immediately before the push, release
  immediately after (even on failure). Never force-push a shared branch.

---

## feature-implementation

`opencode/feature-implementation/SKILL.md` (with
[`agent-contract.md`](../opencode/feature-implementation/agent-contract.md) and
[`worklog-template.md`](../opencode/feature-implementation/worklog-template.md))

**What it does.** Orchestrates implementing a feature through delegated agents.
The primary agent acts as a conductor: it owns scope, phase transitions, report
reconciliation, the shared worklog, follow-up work, and final status.

**When it fires.** Implementing a feature from a source document or session
context where the work benefits from delegated discovery, testing, review, or an
evolving shared plan.

**Key mechanics.**
- Fixed phase sequence: `intake → discovery → planned → implementing → testing →
  reviewing → iterating → complete`, with every transition and rollback recorded
  in `docs/worklogs/<feature-slug>.md`.
- A curated `docs/feature-learnings.md` holds verified, reusable, cross-feature
  guidance; the per-feature worklog holds the complete record.
- Discovery and review run as parallel read-only agents; implementation is
  serial by default. Every agent reads the current worklog first and returns a
  structured report per the agent contract; only the conductor merges reports
  into shared state.
- Ambiguity is a blocking open question — implementation affected by it is
  paused, not guessed.
- Testing adds new tests only for meaningful regression risk or acceptance
  criteria, never to pad coverage. A failing test is preserved as evidence and
  becomes an explicit fix task.
- Completion requires fresh command-level verification after the last change;
  "tests pass" alone is not verification.

**Relation to `/ship`.** This skill is the flexible, adaptive, auditable option.
The `/ship` pipeline is the rigid, push-button alternative — same
plan→code→test→review shape, but fixed models, a flat `.pipeline/` handoff, and a
one-retry cap instead of worklogs and phase bookkeeping.
