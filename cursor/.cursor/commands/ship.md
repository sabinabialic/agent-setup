---
description: Plan, implement, test, review, and open a draft PR for a bounded feature.
---

Run the following autonomous pipeline for this feature request:

$ARGUMENTS

Use the current date and the first approximately six request words, converted to
kebab case, to create `.pipeline/<YYYY-MM-DD>-<slug>/`. Remove and recreate
only that run directory; do not touch other pipeline runs.

1. Explore the repository and write `spec.md`. Include Summary, exact Files,
   Functions & signatures, Data flow, numbered Edge cases, and Out of scope.
   If an ambiguity prevents a safe spec, stop and report it rather than guessing.
2. Implement exactly that spec. Write `changes.md` with Summary, Files changed,
   Deviations, and Notes for tester. Do not add unrelated improvements.
3. Discover the existing test conventions, add only meaningful happy-path and
   specified edge-case tests, run them, and write `tests.md` with Test files,
   Coverage map, and actual Results. Do not alter production code merely to
   make a test pass.
4. Independently inspect the spec, artifacts, and source diff using the
   `pr-review` skill. Write `review.md` beginning with `VERDICT: PASS` or
   `VERDICT: FAIL`, followed by reasoning and categorized, actionable blocking
   issues. A missing spec requirement, meaningful untested edge case, failing
   test, or evidenced production risk is a FAIL.
5. On the first FAIL only, fix every blocking issue, update `changes.md`, rerun
   testing, and overwrite `tests.md` and `review.md`. Never run a third review.
6. Only on PASS, create a unique `ship/<slug>` branch, stage all changes except
   `.pipeline/`, commit a concise summary, push it, and open a draft PR with
   `gh`. Use the `writing-pr-descriptions` skill and the repository PR template
   when present. Write `pr.md` with the branch, commit SHA, PR URL, draft
   confirmation, deferred work, and non-blocking review feedback. Do not
   force-push. If PR mechanics fail, record the exact error under `## BLOCKED`.

Finish with the verdict, retry status, changed files, test results, PR details
or why no PR was opened, remaining blockers, and the pipeline artifact path.
