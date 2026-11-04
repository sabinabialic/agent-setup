---
description: Run the ship pipeline (isolate, plan, code, verify, review, publish a draft PR) on a feature request.
agent: ship
---

Run the ship pipeline for the following feature request:

$ARGUMENTS

Follow your orchestrator instructions exactly: isolate a worktree from the PR base, then dispatch planner, coder, tester, and reviewer, with at most one repair round. Publish through the gate script only on PASS, then give me the final report.
