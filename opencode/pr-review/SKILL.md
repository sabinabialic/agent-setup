---
name: pr-review
description: Use when conducting an orchestrated staff-level review of code on a branch or pull request with independent reviewers and evidence-based triage of correctness, concurrency, scalability, security, operational, and maintainability risks.
---

# PR Review

## Overview
Review the code on this branch as a staff engineer. Use two independent reviewers for
meaningful production risk, then reconcile their reports into evidence-based, actionable
findings. Assess not only local implementation quality, but also how the change behaves
under concurrency, production load, partial failure, evolving requirements, and
operational constraints. For every finding, explain why it matters and what could happen
in production, not just what to change.

## When to Use
- Reviewing a branch or pull request before merge
- Auditing a diff for bugs, security issues, or performance regressions
- Giving a second opinion on code quality before requesting human review
- Evaluating the production readiness and system-level impact of a change

## What to Consider
1. **Correctness and code quality** — idiomatic usage, consistency with existing
   patterns, unnecessary complexity, invalid assumptions, and broken invariants.
2. **Edge cases and failure handling** — null/undefined handling, boundary conditions,
   malformed input, retries, timeouts, cancellation, partial failure, and error
   propagation. Verify failure paths are observable and do not leave corrupt state.
3. **Concurrency and consistency** — race conditions, TOCTOU bugs, non-atomic
   read-modify-write sequences, idempotency, duplicate delivery, transaction boundaries,
   lock contention, deadlocks, and ordering assumptions. Consider concurrent requests,
   multiple workers, and retries explicitly.
4. **Scalability and performance** — algorithmic complexity, N+1 queries, unbounded
   queries or collections, pagination, fan-out, hot partitions, cache behavior,
   connection-pool pressure, rate limits, backpressure, and work that grows with traffic
   or data volume. Favor measured improvements over speculative micro-optimizations.
5. **Security and privacy** — injection risks, unsafe deserialization, secrets in code
   or logs, input validation, authorization at each trust boundary, tenant isolation,
   sensitive-data exposure, and unsafe dependency usage.
6. **Reliability and operability** — graceful degradation, retry safety, circuit
   breaking, resource cleanup, health checks, logging with actionable context, metrics,
   tracing, alertability, and rollback behavior. Identify whether an on-call engineer
   could detect and diagnose failure.
7. **Maintainability and evolution** — naming, module boundaries, public API and schema
   compatibility, migrations, feature-flag lifecycle, testability, documentation for
   non-obvious decisions, and whether the design can accommodate plausible future scale
   or requirements without a rewrite.

## Review Topology

Use two independent, read-only reviewers for changes affecting production behavior,
persistence, authorization, concurrency, public contracts, or meaningful operational
risk. Prefer distinct top-tier coding/reasoning model families when available. For
each reviewer, select a model optimized for code review: strong long-context reasoning,
cross-file analysis, bug detection, and precise evidence-backed reporting. Do not use a
fast or low-cost model for final review findings. For isolated, low-risk changes such as
documentation, use one such reviewer and state that the dual-review fallback was used.

- **Systems reviewer:** emphasizes correctness, edge cases, concurrency, security,
  reliability, scalability, and operational behavior.
- **Change-integrity reviewer:** emphasizes requirements, compatibility, migrations,
  test gaps, maintainability, and evolution.

Both reviewers inspect the complete scoped diff and relevant surrounding code. Give them
the same base branch, diff scope, repository context, and evidence standard. They do not
edit files, share findings before completion, or begin fixes.

## Process
1. Identify the diff scope: prefer `git diff` against the base branch (e.g.
  `git diff main...HEAD`) or the PR's changed files rather than the whole repo.
2. Dispatch the applicable reviewer topology in parallel. Each reviewer reads changed
  files with enough surrounding context to understand intent, not just changed lines.
3. Have each reviewer trace important request, data, and error paths across relevant
  boundaries, including callers, persistence, queues, caches, and external services.
4. For state-changing paths, reason through concurrent execution, retries, duplicate
  events, and interruption at every side-effect boundary. For paths whose cost grows
  with traffic or data, identify the growth factor and assess expected peak load.
5. Collect both reports before triage. Merge equivalent findings and independently
  verify each candidate against the code and repository context. Agreement is a signal,
  not proof; discard unsupported, unreachable, preference-only, or speculative issues.
6. Retain only findings with file and line evidence, a plausible triggering scenario,
  and a concrete recommendation. The triage owner may add a finding only after applying
  the same evidence standard.
7. Distinguish blocking issues from follow-ups. Prioritize by severity, likelihood,
  blast radius, and reversibility, not by the number of stylistic observations.

## Output Format
Organize findings by file, then by severity within each file:
```md
### <file path>
- **[both | systems | change-integrity] [Critical | Security]** <problem> —
  **Scenario:** <triggering conditions>.
  **Impact:** <user/system impact and blast radius>. **Recommendation:** <concrete fix>.
- **[both | systems | change-integrity] [High | Correctness/Concurrency]** <problem> —
  **Scenario:** <triggering conditions>.
  **Impact:** <user/system impact>. **Recommendation:** <concrete fix>.
- **[both | systems | change-integrity] [Medium | Scalability/Reliability]** <problem> —
  **Scenario:** <triggering conditions>.
  **Impact:** <cost, degradation, or operational impact>. **Recommendation:** <concrete fix>.
- **[both | systems | change-integrity] [Low | Maintainability]** <problem> —
  **Reasoning:** <why it will be costly or risky>.
  **Recommendation:** <concrete fix>.
```
Use `Critical` for an imminent severe security, data-loss, or broad outage risk; `High`
for likely correctness or reliability failures; `Medium` for meaningful operational or
scalability risk; and `Low` for non-blocking maintainability improvements.

End with a short summary covering:
- overall risk level and merge recommendation: safe to merge, needs changes, or needs
  design discussion;
- whether the dual-review or single-review fallback was used;
- assumptions that could change the review conclusion;
- remaining risks and the tests, metrics, rollout guardrails, or follow-up work needed
  to manage them.

## Common Mistakes
- Restating the diff instead of evaluating it.
- Treating agreement between reviewers as proof without checking the relevant code.
- Publishing duplicate, unsupported, unreachable, or preference-only findings instead
  of reconciling them first.
- Treating a single-process happy path as proof of correctness when a service may receive
  concurrent requests, retries, or duplicate events.
- Calling code scalable without considering data growth, peak traffic, fan-out, and
  downstream capacity limits.
- Flagging style nits without explaining why they matter, or mixing them with blocking
  issues at the same priority.
- Ignoring surrounding/unchanged code that clarifies whether a "bug" is actually
  reachable.
- Suggesting a fix without explaining the underlying reasoning.
- Recommending distributed-systems complexity, caching, or optimization without evidence
  that the actual workload requires it.
- Ignoring rollout, observability, migrations, and rollback when the change affects
  production behavior or persistent data.
- Reviewing the whole repository when only a branch's diff was requested.
