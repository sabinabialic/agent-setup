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
2. **Plan.** Explore `WT` only enough to find the closest code and tests, and verify what exists rather than guessing. Write `spec.md` in under 50 lines with these sections: Acceptance criteria, Existing implementation, Minimal approach, Edge cases (a numbered list of concrete scenarios the change can actually reach: empty inputs, error paths, concurrency, boundary values, invalid states, failure modes), Interface changes (only if an interface changes), Allowed files with a reason each, Non-goals, Validation, Size estimate, and Assumptions. Be exact: name the function and the behavior, not "add validation". Mirror the allowed files into `allowed-files.txt` and the validation into `checks.txt`. If ambiguity would materially change behavior or architecture, write `NEEDS_SCOPE` and the questions, then stop.
3. **Code and tests.** Implement the change and every contract edge case, with focused regression tests. In the code you change, also handle reachable edge cases the contract missed (null or undefined values, boundaries, malformed input, retries, timeouts and cancellation, partial failure). Validate untrusted input at trust boundaries, and keep secrets and sensitive data out of code and logs. Do not run repo-wide formatters, change lockfiles, commit, or stage. Run `$GATE verify $RUN` and `$GATE scope $RUN code`, and delete files you did not intend to create. Write `changes.md` with Summary, Files, Unlisted files (with reasons), Size (only if `scope` warned), and Deviations. Never compress code or drop tests to get under the size threshold.
4. **Verify.** Re-read the acceptance criteria and edge cases as an independent verifier. Record evidence for each one, flag any edge case you could not test and why, add only missing tests, prove bug-fix regressions with `$GATE regress` when practical, and run `$GATE verify $RUN` after the last edit. Write `tests.md` with Evidence, Added tests, Regression proof, and Failures, classifying each failure as a production or test defect.
5. **Review.** Run `$GATE scope $RUN review`. If you can launch a read-only subagent, have it do the review. Otherwise, review from `request.md`, `spec.md`, `scope.md`, `candidate.patch`, and `checks.tsv` alone, not from memory of writing the code. Use the `pr-review` skill as the standard for these dimensions:
   1. **Spec conformance**: files, signatures where specified, and behavior.
   2. **Correctness**: bugs and logic errors.
   3. **Edge-case coverage**: every contract edge case has a real, meaningful, passing test. Independently, the changed code handles unanticipated edge cases: null or undefined values, boundary conditions, malformed input, retries, timeouts and cancellation, and partial failure.
   4. **Security and vulnerabilities**: injection, unsafe deserialization, secrets in code or logs, missing input validation, authorization gaps at trust boundaries, sensitive-data exposure, and unsafe dependency usage.
   5. **Concurrency and scalability**: races, unsafe shared state, N+1 patterns, unbounded growth, and degradation under load or parallel access.
   6. **Operational risk**: observability, unclear production failure modes, and rollout or rollback.
   7. **Scope**: nothing beyond the contract and nothing missing; unlisted files and size warnings are justified.
   8. **Quality and maintainability**: codebase conventions, coupling, readability, and testability.
   9. **Acceptance**: each criterion is met and evidenced by a passing check.
   10. **Candidate**: the `checks.tsv` hash equals the `scope.md` hash.
   11. **Minimality**: could the requested behavior be delivered with materially less code or fewer changes? Name the specific unnecessary additions.

   Write `review.md` with `VERDICT: PASS` or `VERDICT: FAIL` as its first line.
   - **Blocking:** unmet acceptance criteria or spec behavior; a real bug; a security vulnerability with a plausible exploit path; a contract edge case with no meaningful test; an unhandled edge case in the changed code with real risk of incorrect or unsafe behavior; a concurrency or scalability issue with real risk under load or parallel access; failing or mismatched checks; an unjustified unlisted file; and material unnecessary additions.
   - **Non-blocking only:** speculative hardening without evidence, risks in code the patch does not touch, and style preferences.
   - **Tags:** give each blocking issue an owner (`[coder]`, `[tester]`, `[planner]`) and one category: `[Security]`, `[Edge case]`, `[Correctness]`, `[Concurrency]`, `[Scalability]`, `[Operational]`, `[Spec]`, `[Scope]`, `[Quality]`, `[Acceptance]`, `[Minimality]`, or `[Tests]`.
   - Be specific and actionable: every blocking issue names a file and function.

   Then run `$GATE review $RUN`.
6. **Repair, at most once.** On FAIL, run `$GATE event $RUN repair`. Fix only the blocking issues: contract first, then production code, then tests. Rerun `scope` and `verify`, then review once more. Never run a third review.
7. **Publish.** Only on PASS: run `$GATE gate $RUN`, and stop on failure. Write `pr-title.txt`, `commit-msg.txt`, and `pr-body.md` using the repository PR template or the `writing-pr-descriptions` skill, then run `$GATE publish $RUN`. Only that command stages, commits, pushes, and opens the draft PR.

If the run stops before publication, run `$GATE metrics $RUN <outcome>` with `needs-scope`, `blocked`, `review-fail`, or `gate-failed`. Finish with the verdict and whether the repair round was used, the changed files and sizes from `scope.md`, the check results, the PR URL or why none was opened, any remaining blockers, and the `RUN` path.
