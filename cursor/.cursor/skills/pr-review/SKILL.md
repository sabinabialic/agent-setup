---
name: pr-review
description: Use when reviewing a branch or pull request for production risks before merge.
---

# PR Review

Review the branch diff as a staff engineer. Scope to the target branch or PR,
not the whole repository. Read changed code with its callers and relevant
boundaries before reporting a finding.

Evaluate correctness, failure handling, concurrency and idempotency,
scalability, security and privacy, reliability and operability, and
maintainability. For state changes, reason explicitly about retries, duplicate
delivery, partial failure, and concurrent execution. Only report risks supported
by repository evidence.

For each finding, cite a file and line, give the triggering scenario and likely
production impact, and recommend a concrete fix. Organize findings by file then
severity (`Critical`, `High`, `Medium`, `Low`). Finish with a merge
recommendation, assumptions, and any remaining risk or verification gap.

Do not restate the diff, report style preferences as defects, or praise code
performatively.
