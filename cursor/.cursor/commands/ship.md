---
description: Isolate, plan, implement, verify, review, and publish a draft PR for a bounded feature.
---

Run the ship pipeline for this feature request:

$ARGUMENTS

From the main checkout root, set `GATE=.cursor/scripts/ship-gate.sh` and run every gate command as `SHIP_DIRTY_EXCLUDE=.cursor $GATE ...`. `init` prints `RUN`, `WT`, `BRANCH`, `PR_BASE`, and `BASE_SHA`. Artifacts go in `RUN`, and source edits happen only in `WT`. The script header documents the `allowed-files.txt` and `checks.txt` formats.

Apply this scope rule whenever you edit code or tests:

```
Implement the smallest complete change satisfying the acceptance criteria.
Reuse existing patterns and dependencies.
Avoid unrelated renames, formatting, cleanup, and abstractions.
Before editing an unlisted file, explain why it is necessary.
If implementation requires broader architecture, report NEEDS_SCOPE.
```

1. **Isolate.** Run `$GATE init -- "<request>"`. Add `--base <branch>` only when the request explicitly builds on unmerged branch work. Exit 2 means a dirty checkout or an unresolvable base: stop and report the message, and never stash.
2. **Plan.** Explore `WT` only enough to find the closest code and tests. Write `spec.md` in under 50 lines with these sections: Acceptance criteria, Existing implementation, Minimal approach, Interface changes (only if an interface changes), Allowed files with a reason each, Non-goals, Validation, Size estimate, and Assumptions. Mirror the allowed files into `allowed-files.txt` and the validation into `checks.txt`. If ambiguity would materially change behavior or architecture, write `NEEDS_SCOPE` and the questions, then stop.
3. **Code and tests.** Implement the change with focused regression tests. Do not run repo-wide formatters, change lockfiles, commit, or stage. Run `$GATE verify $RUN` and `$GATE scope $RUN code`, and delete files you did not intend to create. Write `changes.md` with Summary, Files, Unlisted files (with reasons), Size (only if `scope` warned), and Deviations. Never compress code or drop tests to get under the size threshold.
4. **Verify.** Re-read the acceptance criteria as an independent verifier. Record evidence for each one, add only missing tests, prove bug-fix regressions with `$GATE regress` when practical, and run `$GATE verify $RUN` after the last edit. Write `tests.md` with Evidence, Added tests, Regression proof, and Failures, classifying each failure as a production or test defect.
5. **Review.** Run `$GATE scope $RUN review`. If you can launch a read-only subagent, have it do the review. Otherwise, review from `request.md`, `scope.md`, `candidate.patch`, and `checks.tsv` alone, not from memory of writing the code. Apply the `pr-review` skill and ask: could the requested behavior be delivered with materially less code or fewer changes? Name the specific unnecessary additions. Write `review.md` with `VERDICT: PASS` or `VERDICT: FAIL` as its first line, followed by owner-tagged (`[coder]`, `[tester]`, `[planner]`) blocking issues. Only unmet acceptance criteria, real bugs or security issues in changed code, failing required checks, unjustified unlisted files, and material unnecessary additions block. Then run `$GATE review $RUN`.
6. **Repair, at most once.** On FAIL, run `$GATE event $RUN repair`. Fix only the blocking issues: contract first, then production code, then tests. Rerun `scope` and `verify`, then review once more. Never run a third review.
7. **Publish.** Only on PASS: run `$GATE gate $RUN`, and stop on failure. Write `pr-title.txt`, `commit-msg.txt`, and `pr-body.md` using the repository PR template or the `writing-pr-descriptions` skill, then run `$GATE publish $RUN`. Only that command stages, commits, pushes, and opens the draft PR.

If the run stops before publication, run `$GATE metrics $RUN <outcome>` with `needs-scope`, `blocked`, `review-fail`, or `gate-failed`. Finish with the verdict and whether the repair round was used, the changed files and sizes from `scope.md`, the check results, the PR URL or why none was opened, any remaining blockers, and the `RUN` path.
