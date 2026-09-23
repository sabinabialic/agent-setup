---
name: pr-review
description: Use when conducting a staff-level review of code on a branch or pull request, identifying correctness, concurrency, scalability, security, operational, and maintainability risks with prioritized, actionable suggestions.
---

# PR Review

## Overview
Review the code on this branch as a staff engineer: assess not only local implementation
quality, but also how the change behaves under concurrency, production load, partial
failure, evolving requirements, and operational constraints. Provide concrete, actionable
suggestions. For every finding, explain why it matters and what could happen in
production, not just what to change.

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

## Process
1. Identify the diff scope: prefer `git diff` against the base branch (e.g.
   `git diff main...HEAD`) or the PR's changed files rather than the whole repo.
2. Read each changed file with enough surrounding context to understand intent, not
   just the changed lines in isolation.
3. Trace important request, data, and error paths across relevant boundaries, including
   callers, persistence, queues, caches, and external services.
4. For state-changing paths, reason through concurrent execution, retries, duplicate
   events, and interruption at every side-effect boundary.
5. For paths whose cost grows with traffic or data, identify the growth factor and
   assess behavior at expected peak load, not only the current happy-path volume.
6. Work through all considerations above for each meaningful change. Do not invent
   findings: report risks only when the code and repository context provide evidence.
7. For each issue, cite the specific file and line, describe the triggering scenario,
   production impact, and a concrete fix.
8. Distinguish blocking issues from follow-ups. Prioritize by severity, likelihood,
   blast radius, and reversibility—not by the number of stylistic observations.

## Output Format
Organize findings by file, then by severity within each file:
```md
### <file path>
- **[Critical | Security]** <problem> — **Scenario:** <triggering conditions>.
  **Impact:** <user/system impact and blast radius>. **Recommendation:** <concrete fix>.
- **[High | Correctness/Concurrency]** <problem> — **Scenario:** <triggering conditions>.
  **Impact:** <user/system impact>. **Recommendation:** <concrete fix>.
- **[Medium | Scalability/Reliability]** <problem> — **Scenario:** <triggering conditions>.
  **Impact:** <cost, degradation, or operational impact>. **Recommendation:** <concrete fix>.
- **[Low | Maintainability]** <problem> — **Reasoning:** <why it will be costly or risky>.
  **Recommendation:** <concrete fix>.
```
Use `Critical` for an imminent severe security, data-loss, or broad outage risk; `High`
for likely correctness or reliability failures; `Medium` for meaningful operational or
scalability risk; and `Low` for non-blocking maintainability improvements.

End with a short summary covering:
- overall risk level and merge recommendation: safe to merge, needs changes, or needs
  design discussion;
- assumptions that could change the review conclusion;
- remaining risks and the tests, metrics, rollout guardrails, or follow-up work needed
  to manage them.

## Common Mistakes
- Restating the diff instead of evaluating it.
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

