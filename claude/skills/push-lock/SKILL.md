---
name: push-lock
description: Use when multiple agents may push to the same branch or repository concurrently and pushes must be serialized to avoid non-fast-forward errors, lost updates, or force-push conflicts.
---

# Coordinating Push Locks

## Overview
When multiple agents write code against the same repository concurrently, only the
push step needs mutual exclusion — edits, tests, and review can run in parallel.
Use a git-native, atomic lock ref so no external coordination service is required.

## When to Use
- Multiple agents (or agent instances) may finish work and push around the same time.
- Pushes target a shared branch, not each agent's own isolated branch.
- You've seen non-fast-forward rejections, silent lost commits, or force-push
  overwrites from concurrent agent activity.

## When Not to Use
- Each agent pushes to its own uniquely named branch (no shared ref, no conflict).
- Only one agent can push at a time by construction (e.g. single conductor process).

## Lock Mechanism
Use a dedicated ref as the lock, created with an atomic, race-free git operation:

1. **Acquire:** attempt to create `refs/locks/push` pointing at a lease commit that
   encodes the holder id and acquisition time:
   ```bash
   git push origin <local-lease-commit>:refs/locks/push
   ```
   This fails if the ref already exists, so exactly one concurrent attempt succeeds.
   Do not use a local file or in-memory flag as the lock — it is invisible to other
   agents/processes and does not prevent cross-agent races.
2. **Retry with backoff:** on failure, read the existing lock's timestamp. If younger
   than the TTL (e.g. 5 minutes), wait and retry. If older, treat it as stale
   (crashed holder) and force-reclaim it, logging that a stale lock was reclaimed.
3. **Rebase before pushing:** after acquiring the lock, `git fetch` and rebase (or
   fast-forward merge) onto the current remote branch tip. The lock only guarantees
   exclusivity among cooperating agents, not exclusivity against all remote activity.
4. **Push:** push the target branch normally (never force-push a shared branch).
5. **Release:** delete the lock ref (`git push origin :refs/locks/push`) immediately
   after the push completes or fails. Release must run even if the push step errors.

## Required Properties
- **Atomic acquisition** — the acquire step itself must not have a race window;
  rely on git's ref-creation rejection, not a check-then-act sequence.
- **Bounded hold time** — every lock has a TTL. Never hold the lock across long
  operations (tests, review, editing); acquire immediately before the push and
  release immediately after.
- **Always released** — treat release as mandatory cleanup, not best-effort;
  a stuck lock blocks every other agent until TTL expiry.
- **Idempotent retry** — an agent that failed mid-push (lock acquired, push failed)
  must release the lock before retrying, not leave it held.

## Common Mistakes
- Using a local file, in-process mutex, or unpublished flag as the lock — it has no
  effect on a different agent/process/machine.
- Holding the lock across editing, testing, or review instead of only the push.
- Skipping the fetch+rebase step after acquiring the lock, causing a stale-base push.
- No TTL/staleness check, so a crashed agent permanently blocks all future pushes.
- Force-pushing to resolve a rejected push instead of rebasing, which can silently
  discard another agent's already-pushed commits.
- Treating lock acquisition success as proof the branch is up to date — it only
  proves exclusivity, not freshness.
