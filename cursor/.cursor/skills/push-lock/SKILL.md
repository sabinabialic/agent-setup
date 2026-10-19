---
name: push-lock
description: Use when multiple agents may push concurrently to the same shared branch.
---

# Push Lock

Only serialize the push step. Use the atomic remote ref `refs/locks/push`, not
a local file or in-memory mutex. Acquire it with a lease commit immediately
before pushing; on contention, retry with backoff and reclaim only a lock older
than its TTL. After acquisition, fetch and rebase onto the remote branch tip,
push normally, then delete the lock even when the push fails.

Never hold the lock while editing, testing, or reviewing. Never force-push a
shared branch. This is unnecessary when every agent has its own branch.
